defmodule Claptrap.Producer.RouterTest do
  use Claptrap.DataCase, async: false

  alias Claptrap.{Catalog, PubSub}
  alias Claptrap.Producer.Router
  alias Claptrap.Registry

  @source_attrs %{type: "rss", name: "Feed", config: %{"url" => "https://example.com/feed"}}
  @sink_attrs %{
    type: "rss_feed",
    name: "My RSS Feed",
    config: %{"description" => "A combined feed"}
  }

  # Stop the Producer.Supervisor so we can control
  # Router startup timing per-test
  setup do
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

    start_supervised!({DynamicSupervisor, strategy: :one_for_one, name: Claptrap.Producer.WorkerSupervisor})

    :ok
  end

  describe "Producer.Router" do
    test "starts successfully" do
      start_supervised!(Router)
      assert Process.whereis(Router) |> is_pid()
    end

    test "subscribes to entries:new PubSub on init" do
      start_supervised!(Router)
      PubSub.broadcast(PubSub.topic_entries_new(), {:entries_ingested, "src-1", []})
      :sys.get_state(Router)
      assert Process.alive?(Process.whereis(Router))
    end

    test "bootstraps workers for enabled sinks on init" do
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      start_supervised!(Router)
      assert is_pid(Registry.whereis(:sink_worker, sink.id))
    end

    test "does not start workers for disabled sinks" do
      {:ok, sink} = Catalog.create_sink(Map.put(@sink_attrs, :enabled, false))
      start_supervised!(Router)
      assert Registry.whereis(:sink_worker, sink.id) == :undefined
    end

    test "routes entries with matching tags to the correct worker" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})

      start_supervised!(Router)
      worker_pid = Registry.whereis(:sink_worker, sink.id)
      assert is_pid(worker_pid)

      {:ok, entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "e1",
          title: "Hello",
          status: "unread",
          tags: ["elixir"]
        })

      :ets.delete(:claptrap_rss_feeds, sink.id)
      PubSub.broadcast(PubSub.topic_entries_new(), {:entries_ingested, source.id, [entry]})

      # Ensure Router processes the message, then drain the Worker's mailbox
      :sys.get_state(Router)
      :sys.get_state(worker_pid)

      assert [{_sink_id, {xml, _}}] = :ets.lookup(:claptrap_rss_feeds, sink.id)
      assert xml =~ "<rss"
    end

    test "does not route entries with non-overlapping tags" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})

      start_supervised!(Router)
      worker_pid = Registry.whereis(:sink_worker, sink.id)
      assert is_pid(worker_pid)

      {:ok, entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "e-rust",
          title: "Rust News",
          status: "unread",
          tags: ["rust"]
        })

      :ets.delete(:claptrap_rss_feeds, sink.id)
      PubSub.broadcast(PubSub.topic_entries_new(), {:entries_ingested, source.id, [entry]})
      :sys.get_state(Router)
      :sys.get_state(worker_pid)

      assert [] = :ets.lookup(:claptrap_rss_feeds, sink.id)
    end

    test "fans out to multiple sinks with different subscriptions" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink1} = Catalog.create_sink(@sink_attrs)
      {:ok, sink2} = Catalog.create_sink(%{@sink_attrs | name: "Sink 2"})
      {:ok, _sub1} = Catalog.create_subscription(%{sink_id: sink1.id, tags: ["elixir"]})
      {:ok, _sub2} = Catalog.create_subscription(%{sink_id: sink2.id, tags: ["elixir"]})

      start_supervised!(Router)
      worker1 = Registry.whereis(:sink_worker, sink1.id)
      worker2 = Registry.whereis(:sink_worker, sink2.id)

      {:ok, entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "both",
          title: "Both Match",
          status: "unread",
          tags: ["elixir"]
        })

      :ets.delete(:claptrap_rss_feeds, sink1.id)
      :ets.delete(:claptrap_rss_feeds, sink2.id)

      PubSub.broadcast(PubSub.topic_entries_new(), {:entries_ingested, source.id, [entry]})
      :sys.get_state(Router)
      :sys.get_state(worker1)
      :sys.get_state(worker2)

      assert [{_, _}] = :ets.lookup(:claptrap_rss_feeds, sink1.id)
      assert [{_, _}] = :ets.lookup(:claptrap_rss_feeds, sink2.id)
    end
  end
end
