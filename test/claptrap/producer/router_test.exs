defmodule Claptrap.Producer.RouterTest do
  use Claptrap.DataCase, async: false

  @moduletag :integration
  @moduletag capture_log: true

  alias Claptrap.Catalog
  alias Claptrap.Producer.{Router, Worker}
  alias Claptrap.Registry, as: Reg

  @source_attrs %{type: "rss", name: "Source", config: %{"url" => "https://example.com/feed"}}
  @sink_attrs %{
    type: "rss",
    name: "Test Sink",
    config: %{"description" => "Test feed"}
  }

  setup do
    Supervisor.terminate_child(Claptrap.Supervisor, Claptrap.Producer.Supervisor)
    Process.sleep(20)

    try do
      :ets.new(:claptrap_rss_feeds, [:named_table, :public, :set, read_concurrency: true])
    rescue
      ArgumentError -> :ok
    end

    # Start a DynamicSupervisor so Router.bootstrap_workers can start children
    start_supervised!({DynamicSupervisor, strategy: :one_for_one, name: Claptrap.Producer.WorkerSupervisor})

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

  describe "start_link/1" do
    test "starts successfully" do
      pid = start_supervised!(Router)
      assert is_pid(pid)
    end
  end

  describe "PubSub subscription" do
    test "subscribes to entries:new on init" do
      start_supervised!(Router)
      topic = Claptrap.PubSub.topic_entries_new()
      Claptrap.PubSub.broadcast(topic, {:entries_ingested, "src-1", []})
      # Router is alive after receiving the message
      assert Process.whereis(Router) |> Process.alive?()
    end
  end

  describe "routing" do
    test "routes entries with matching tags to the correct worker" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})

      start_supervised!({Worker, sink.id})
      start_supervised!(Router)

      {:ok, entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "ext-1",
          title: "Elixir Post",
          url: "https://example.com/1",
          status: "unread",
          tags: ["elixir"]
        })

      pid = Process.whereis(Router)
      send(pid, {:entries_ingested, source.id, [entry]})

      # Wait for async processing
      _ = :sys.get_state(pid)

      # Give worker time to process
      worker_pid = Reg.whereis(:sink_worker, sink.id)
      _ = :sys.get_state(worker_pid)

      sid = sink.id
      [{^sid, {xml, _}}] = :ets.lookup(:claptrap_rss_feeds, sink.id)
      assert xml =~ "Elixir Post"
    end

    test "does not route entries with non-overlapping tags" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["rust"]})

      start_supervised!({Worker, sink.id})
      start_supervised!(Router)

      {:ok, entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "ext-1",
          title: "Python Post",
          status: "unread",
          tags: ["python"]
        })

      pid = Process.whereis(Router)
      send(pid, {:entries_ingested, source.id, [entry]})
      _ = :sys.get_state(pid)

      # Worker should not have materialized with this entry
      worker_pid = Reg.whereis(:sink_worker, sink.id)
      _ = :sys.get_state(worker_pid)

      case :ets.lookup(:claptrap_rss_feeds, sink.id) do
        [{_, {xml, _}}] -> refute xml =~ "Python Post"
        [] -> :ok
      end
    end

    test "multi-sink fan-out: one entry matches two sinks" do
      {:ok, source} = Catalog.create_source(@source_attrs)

      {:ok, sink1} = Catalog.create_sink(%{@sink_attrs | name: "Sink One"})
      {:ok, sink2} = Catalog.create_sink(%{@sink_attrs | name: "Sink Two"})
      {:ok, _sub1} = Catalog.create_subscription(%{sink_id: sink1.id, tags: ["elixir"]})
      {:ok, _sub2} = Catalog.create_subscription(%{sink_id: sink2.id, tags: ["elixir"]})

      start_supervised!({Worker, sink1.id}, id: :worker1)
      start_supervised!({Worker, sink2.id}, id: :worker2)
      start_supervised!(Router)

      {:ok, entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "ext-1",
          title: "Shared Post",
          status: "unread",
          tags: ["elixir"]
        })

      pid = Process.whereis(Router)
      send(pid, {:entries_ingested, source.id, [entry]})
      _ = :sys.get_state(pid)

      w1 = Reg.whereis(:sink_worker, sink1.id)
      w2 = Reg.whereis(:sink_worker, sink2.id)
      _ = :sys.get_state(w1)
      _ = :sys.get_state(w2)

      [{_, {xml1, _}}] = :ets.lookup(:claptrap_rss_feeds, sink1.id)
      [{_, {xml2, _}}] = :ets.lookup(:claptrap_rss_feeds, sink2.id)
      assert xml1 =~ "Shared Post"
      assert xml2 =~ "Shared Post"
    end

    test "entries with empty tags do not trigger routing" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir"]})

      start_supervised!({Worker, sink.id})
      start_supervised!(Router)

      {:ok, entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "ext-1",
          title: "Tagless Post",
          status: "unread",
          tags: []
        })

      pid = Process.whereis(Router)
      send(pid, {:entries_ingested, source.id, [entry]})
      _ = :sys.get_state(pid)

      worker_pid = Reg.whereis(:sink_worker, sink.id)
      _ = :sys.get_state(worker_pid)

      case :ets.lookup(:claptrap_rss_feeds, sink.id) do
        [{_, {xml, _}}] -> refute xml =~ "Tagless Post"
        [] -> :ok
      end
    end

    test "partial tag overlap matches the subscription" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      {:ok, sink} = Catalog.create_sink(@sink_attrs)
      {:ok, _sub} = Catalog.create_subscription(%{sink_id: sink.id, tags: ["elixir", "otp"]})

      start_supervised!({Worker, sink.id})
      start_supervised!(Router)

      {:ok, entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "ext-1",
          title: "Partial Match",
          status: "unread",
          tags: ["elixir", "unrelated"]
        })

      pid = Process.whereis(Router)
      send(pid, {:entries_ingested, source.id, [entry]})
      _ = :sys.get_state(pid)

      worker_pid = Reg.whereis(:sink_worker, sink.id)
      _ = :sys.get_state(worker_pid)

      sid = sink.id
      [{^sid, {xml, _}}] = :ets.lookup(:claptrap_rss_feeds, sink.id)
      assert xml =~ "Partial Match"
    end
  end

  describe "handle_info/2" do
    test "handles resource_changed messages gracefully" do
      pid = start_supervised!(Router)
      send(pid, {:resource_changed, :sink, :create, Ecto.UUID.generate()})
      assert Process.alive?(pid)
      _ = :sys.get_state(pid)
    end

    test "handles unexpected messages gracefully" do
      pid = start_supervised!(Router)
      send(pid, :some_garbage)
      _ = :sys.get_state(pid)
      assert Process.alive?(pid)
    end
  end
end
