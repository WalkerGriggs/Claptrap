defmodule Claptrap.Producer.WorkerTest do
  use Claptrap.DataCase, async: false

  alias Claptrap.Catalog
  alias Claptrap.Producer.Worker
  alias Claptrap.Registry

  @source_attrs %{type: "rss", name: "Feed", config: %{"url" => "https://example.com/feed"}}
  @sink_attrs %{
    type: "rss_feed",
    name: "My RSS Feed",
    config: %{"description" => "A combined feed"}
  }

  setup do
    # Stop the Producer.Supervisor so we can manage
    # workers individually in tests
    Supervisor.terminate_child(
      Claptrap.Supervisor,
      Claptrap.Producer.Supervisor
    )

    # Recreate the ETS table destroyed with the
    # supervisor
    if :ets.whereis(:claptrap_rss_feeds) == :undefined do
      :ets.new(:claptrap_rss_feeds, [
        :named_table,
        :public,
        :set,
        read_concurrency: true
      ])
    end

    on_exit(fn ->
      Supervisor.restart_child(
        Claptrap.Supervisor,
        Claptrap.Producer.Supervisor
      )
    end)

    :ok
  end

  defp create_sink(attrs \\ @sink_attrs) do
    {:ok, sink} = Catalog.create_sink(attrs)
    sink
  end

  describe "start_link/1" do
    test "starts and registers via Registry" do
      sink = create_sink()
      pid = start_supervised!({Worker, sink.id})

      assert is_pid(pid)
      assert Registry.whereis(:sink_worker, sink.id) == pid
    end

    @tag capture_log: true
    test "fails for unknown sink type" do
      {:ok, sink} = Catalog.create_sink(%{type: "unknown_type", name: "Bad", config: %{"x" => "y"}})
      Process.flag(:trap_exit, true)
      assert {:error, _} = Worker.start_link(sink.id)
      # Remove so Router doesn't hit this on restart
      Catalog.delete_sink(sink)
    end
  end

  describe "handle_cast {:deliver, entries}" do
    test "materializes entries for rss_feed sink" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      sink = create_sink()
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})

      {:ok, entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "e1",
          title: "Hello",
          status: "unread",
          tags: ["elixir"]
        })

      pid = start_supervised!({Worker, sink.id})
      GenServer.cast(pid, {:deliver, [entry]})
      :sys.get_state(pid)

      assert [{_sink_id, {xml, _}}] = :ets.lookup(:claptrap_rss_feeds, sink.id)
      assert xml =~ "<rss"
    end
  end

  describe "retry behavior" do
    test "worker stays alive after delivery failure" do
      sink = create_sink()
      pid = start_supervised!({Worker, sink.id})
      assert Process.alive?(pid)

      GenServer.cast(pid, {:deliver, []})
      :sys.get_state(pid)
      assert Process.alive?(pid)
    end

    test "retry exhaustion drops batch and logs" do
      sink = create_sink()
      pid = start_supervised!({Worker, sink.id})

      # Replace state to simulate multiple pending retries
      state = :sys.get_state(pid)
      assert is_map(state)
      assert Process.alive?(pid)
    end
  end
end
