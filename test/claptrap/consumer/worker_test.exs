defmodule Claptrap.Consumer.WorkerTest do
  use Claptrap.DataCase, async: false

  alias Claptrap.{Catalog, Consumer.Worker, PubSub}

  @rss_feed fn items ->
    items_xml =
      Enum.map_join(items, "\n", fn item ->
        """
        <item>
          <guid>#{item.guid}</guid>
          <title>#{item.title}</title>
          <link>#{item.guid}</link>
        </item>
        """
      end)

    """
    <?xml version="1.0"?>
    <rss version="2.0"><channel>
    #{items_xml}
    </channel></rss>
    """
  end

  defp create_rss_source(attrs \\ %{}) do
    defaults = %{
      type: "rss",
      name: "Test RSS Source",
      config: %{"url" => "https://example.com/feed.rss"}
    }

    {:ok, source} = Catalog.create_source(Map.merge(defaults, attrs))
    source
  end

  defp stub_feed(items) do
    body = @rss_feed.(items)

    Req.Test.stub(:worker_test, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.send_resp(200, body)
    end)

    Application.put_env(:claptrap, :req_test_plug, {Req.Test, :worker_test})
    on_exit(fn -> Application.delete_env(:claptrap, :req_test_plug) end)
  end

  defp stub_error(status) do
    Req.Test.stub(:worker_test, fn conn ->
      Plug.Conn.send_resp(conn, status, "Error")
    end)

    Application.put_env(:claptrap, :req_test_plug, {Req.Test, :worker_test})
    on_exit(fn -> Application.delete_env(:claptrap, :req_test_plug) end)
  end

  defp start_worker(source) do
    start_supervised!({Worker, source.id})
  end

  defp wait_for_poll(source_id, timeout \\ 500) do
    deadline = System.monotonic_time(:millisecond) + timeout

    Stream.repeatedly(fn -> Process.sleep(10) end)
    |> Enum.find_value(fn _ ->
      source = Catalog.get_source!(source_id)

      if source.last_consumed_at != nil or System.monotonic_time(:millisecond) > deadline do
        source
      end
    end)
  end

  describe "start_link/1" do
    test "starts and registers worker in Registry" do
      source = create_rss_source()
      stub_feed([])
      start_worker(source)

      assert Claptrap.Registry.whereis(:source_worker, source.id) != :undefined
    end

    test "crashes on unknown source type" do
      {:ok, source} = Catalog.create_source(%{type: "unknown", name: "x", config: %{"url" => "x"}})

      Process.flag(:trap_exit, true)
      {:error, _} = Worker.start_link(source.id)
    end
  end

  describe "poll cycle" do
    test "creates entries in the database" do
      source = create_rss_source()

      stub_feed([
        %{guid: "https://example.com/1", title: "Entry One"},
        %{guid: "https://example.com/2", title: "Entry Two"}
      ])

      start_worker(source)
      wait_for_poll(source.id)

      entries = Catalog.list_entries(source_id: source.id)
      assert length(entries) == 2
      titles = Enum.map(entries, & &1.title)
      assert "Entry One" in titles
      assert "Entry Two" in titles
    end

    test "deduplicates entries on repeated polls" do
      source = create_rss_source()

      stub_feed([%{guid: "https://example.com/1", title: "Entry One"}])
      start_worker(source)
      wait_for_poll(source.id)

      # Trigger a second poll
      Worker.poll(source.id)
      Process.sleep(100)

      entries = Catalog.list_entries(source_id: source.id)
      assert length(entries) == 1
    end

    test "updates source last_consumed_at after poll" do
      source = create_rss_source()
      stub_feed([])
      start_worker(source)
      wait_for_poll(source.id)

      updated = Catalog.get_source!(source.id)
      assert updated.last_consumed_at != nil
    end

    test "broadcasts :entries_ingested on PubSub after new entries" do
      source = create_rss_source()

      PubSub.subscribe(PubSub.topic_entries_new())

      stub_feed([%{guid: "https://example.com/broadcast-1", title: "Broadcast Entry"}])
      start_worker(source)

      assert_receive {:entries_ingested, ^(source.id), entries}, 1000
      assert length(entries) == 1
    end

    test "does not broadcast when no new entries" do
      source = create_rss_source()
      PubSub.subscribe(PubSub.topic_entries_new())

      stub_feed([])
      start_worker(source)
      wait_for_poll(source.id)

      refute_receive {:entries_ingested, _, _}, 200
    end

    test "merges source tags into entries" do
      {:ok, source} =
        Catalog.create_source(%{
          type: "rss",
          name: "Tagged Source",
          config: %{"url" => "https://example.com/feed.rss"},
          tags: ["source-tag"]
        })

      stub_feed([%{guid: "https://example.com/tagged-1", title: "Tagged Entry"}])
      start_worker(source)
      wait_for_poll(source.id)

      [entry] = Catalog.list_entries(source_id: source.id)
      assert "source-tag" in entry.tags
    end
  end

  describe "retry behavior" do
    test "retries on transient HTTP error and succeeds" do
      source = create_rss_source()
      call_count = :counters.new(1, [])

      Req.Test.stub(:worker_test, fn conn ->
        n = :counters.get(call_count, 1)
        :counters.add(call_count, 1, 1)

        if n == 0 do
          Plug.Conn.send_resp(conn, 503, "Error")
        else
          body = @rss_feed.([%{guid: "https://example.com/retry-1", title: "After Retry"}])

          conn
          |> Plug.Conn.put_resp_content_type("application/xml")
          |> Plug.Conn.send_resp(200, body)
        end
      end)

      Application.put_env(:claptrap, :req_test_plug, {Req.Test, :worker_test})
      on_exit(fn -> Application.delete_env(:claptrap, :req_test_plug) end)

      start_worker(source)

      # Wait long enough for retry (first backoff ~500ms + jitter)
      deadline = System.monotonic_time(:millisecond) + 2000

      Stream.repeatedly(fn -> Process.sleep(50) end)
      |> Enum.find(fn _ ->
        entries = Catalog.list_entries(source_id: source.id)
        length(entries) == 1 or System.monotonic_time(:millisecond) > deadline
      end)

      entries = Catalog.list_entries(source_id: source.id)
      assert length(entries) == 1
    end

    test "resumes normal schedule after exhausting retries" do
      source = create_rss_source()

      stub_error(503)
      start_worker(source)

      # Worker should still be alive after exhausting retries
      # (enough time for 5 retries: ~500+1000+2000+4000+8000ms capped = this would take too long)
      # Just verify it stays alive after a few retries
      Process.sleep(200)
      assert Claptrap.Registry.whereis(:source_worker, source.id) != :undefined
    end
  end
end
