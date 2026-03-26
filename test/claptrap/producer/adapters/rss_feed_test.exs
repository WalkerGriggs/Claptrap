defmodule Claptrap.Producer.Adapters.RssFeedTest do
  use Claptrap.DataCase, async: false

  @moduletag :integration
  @moduletag capture_log: true

  alias Claptrap.Catalog
  alias Claptrap.Catalog.Sink
  alias Claptrap.Producer.Adapters.RssFeed

  @source_attrs %{type: "rss", name: "Source", config: %{"url" => "https://example.com/feed"}}
  @sink_attrs %{
    type: "rss",
    name: "My Feed",
    config: %{"description" => "A test feed"}
  }

  setup do
    Supervisor.terminate_child(Claptrap.Supervisor, Claptrap.Producer.Supervisor)
    Process.sleep(20)

    try do
      :ets.new(:claptrap_rss_feeds, [:named_table, :public, :set, read_concurrency: true])
    rescue
      ArgumentError -> :ok
    end

    on_exit(fn ->
      try do
        :ets.delete_all_objects(:claptrap_rss_feeds)
      rescue
        ArgumentError -> :ok
      end

      ExUnit.CaptureLog.capture_log(fn ->
        Supervisor.restart_child(Claptrap.Supervisor, Claptrap.Producer.Supervisor)
      end)
    end)

    :ok
  end

  describe "mode/0" do
    test "returns :pull" do
      assert RssFeed.mode() == :pull
    end
  end

  describe "push/2" do
    test "returns error not_supported" do
      sink = %Sink{id: Ecto.UUID.generate(), name: "Test", config: %{}}
      assert {:error, :not_supported} = RssFeed.push(sink, [])
    end
  end

  describe "validate_config/1" do
    test "accepts valid config with description" do
      assert :ok = RssFeed.validate_config(%{"description" => "A feed"})
    end

    test "accepts config with description and max_entries" do
      assert :ok = RssFeed.validate_config(%{"description" => "A feed", "max_entries" => 25})
    end

    test "rejects config without description" do
      assert {:error, "missing required key: description"} = RssFeed.validate_config(%{"max_entries" => 25})
    end

    test "rejects config with non-integer max_entries" do
      assert {:error, "max_entries must be a positive integer"} =
               RssFeed.validate_config(%{"description" => "A feed", "max_entries" => "fifty"})
    end

    test "rejects config with zero max_entries" do
      assert {:error, "max_entries must be a positive integer"} =
               RssFeed.validate_config(%{"description" => "A feed", "max_entries" => 0})
    end

    test "rejects config with negative max_entries" do
      assert {:error, "max_entries must be a positive integer"} =
               RssFeed.validate_config(%{"description" => "A feed", "max_entries" => -5})
    end

    test "rejects non-map config" do
      assert {:error, "config must be a map"} = RssFeed.validate_config("bad")
    end
  end

  describe "materialize/2" do
    test "produces valid RSS 2.0 XML and stores in ETS" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})

      {:ok, entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "ext-1",
          title: "Hello Elixir",
          url: "https://example.com/1",
          summary: "A post about Elixir",
          author: "Author One",
          published_at: ~U[2026-01-15 10:00:00.000000Z],
          status: "unread",
          tags: ["elixir"]
        })

      assert :ok = RssFeed.materialize(sink, [])

      assert {:ok, xml, _updated_at} = RssFeed.get_feed(sink.id)
      assert xml =~ ~r/<rss version="2.0">/
      assert xml =~ "<title>My Feed</title>"
      assert xml =~ "<description>A test feed</description>"
      assert xml =~ "<title>Hello Elixir</title>"
      assert xml =~ "<link>https://example.com/1</link>"
      assert xml =~ "<description>A post about Elixir</description>"
      assert xml =~ "<author>Author One</author>"
      assert xml =~ "<guid isPermaLink=\"false\">#{entry.id}</guid>"
    end

    test "XML contains entries in correct order (newest first)" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})

      {:ok, _} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "old",
          title: "Old Post",
          status: "unread",
          tags: ["elixir"]
        })

      Process.sleep(10)

      {:ok, _} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "new",
          title: "New Post",
          status: "unread",
          tags: ["elixir"]
        })

      assert :ok = RssFeed.materialize(sink, [])
      {:ok, xml, _} = RssFeed.get_feed(sink.id)

      old_pos = :binary.match(xml, "Old Post") |> elem(0)
      new_pos = :binary.match(xml, "New Post") |> elem(0)
      assert new_pos < old_pos
    end

    test "handles entries with nil optional fields" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["test"]})

      {:ok, _} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "minimal",
          title: "Minimal",
          status: "unread",
          tags: ["test"]
        })

      assert :ok = RssFeed.materialize(sink, [])
      {:ok, xml, _} = RssFeed.get_feed(sink.id)
      assert xml =~ "<title>Minimal</title>"
      assert xml =~ "<link></link>"
      assert xml =~ "<description></description>"
      assert xml =~ "<author></author>"
    end

    test "respects max_entries config" do
      {:ok, source} = Catalog.create_source(@source_attrs)

      {:ok, sink} =
        Catalog.create_sink(%{
          type: "rss",
          name: "Limited Feed",
          config: %{"description" => "Limited", "max_entries" => 2}
        })

      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})

      for i <- 1..5 do
        {:ok, _} =
          Catalog.create_entry(%{
            source_id: source.id,
            external_id: "e#{i}",
            title: "Entry #{i}",
            status: "unread",
            tags: ["elixir"]
          })
      end

      assert :ok = RssFeed.materialize(sink, [])
      {:ok, xml, _} = RssFeed.get_feed(sink.id)

      item_count = xml |> String.split("<item>") |> length() |> Kernel.-(1)
      assert item_count == 2
    end

    test "escapes special XML characters" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["test"]})

      {:ok, _} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "special",
          title: "Foo & Bar <baz>",
          summary: "It's a \"test\"",
          status: "unread",
          tags: ["test"]
        })

      assert :ok = RssFeed.materialize(sink, [])
      {:ok, xml, _} = RssFeed.get_feed(sink.id)
      assert xml =~ "Foo &amp; Bar &lt;baz&gt;"
      assert xml =~ "It&apos;s a &quot;test&quot;"
    end

    test "produces a feed with zero items when no entries match" do
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})

      assert :ok = RssFeed.materialize(sink, [])
      {:ok, xml, _} = RssFeed.get_feed(sink.id)

      assert xml =~ "<title>My Feed</title>"
      refute xml =~ "<item>"
    end

    test "re-materialization overwrites previous feed" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})

      assert :ok = RssFeed.materialize(sink, [])
      {:ok, xml1, _} = RssFeed.get_feed(sink.id)
      refute xml1 =~ "<item>"

      {:ok, _} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "ext-1",
          title: "New Entry",
          status: "unread",
          tags: ["elixir"]
        })

      assert :ok = RssFeed.materialize(sink, [])
      {:ok, xml2, _} = RssFeed.get_feed(sink.id)
      assert xml2 =~ "New Entry"
    end
  end

  describe "get_feed/1" do
    test "returns :not_found when no feed exists" do
      assert {:error, :not_found} = RssFeed.get_feed(Ecto.UUID.generate())
    end
  end
end
