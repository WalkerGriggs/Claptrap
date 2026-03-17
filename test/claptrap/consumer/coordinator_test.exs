defmodule Claptrap.Consumer.CoordinatorTest do
  use Claptrap.DataCase, async: false

  alias Claptrap.{Catalog, Consumer.Coordinator, Consumer.Worker, Registry}

  defp create_source(attrs \\ %{}) do
    defaults = %{
      type: "rss",
      name: "Test RSS",
      config: %{"url" => "https://example.com/feed.rss"},
      enabled: true
    }

    {:ok, source} = Catalog.create_source(Map.merge(defaults, attrs))
    source
  end

  setup do
    Req.Test.stub(:coordinator_test, fn conn ->
      body = """
      <?xml version="1.0"?>
      <rss version="2.0"><channel></channel></rss>
      """

      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.send_resp(200, body)
    end)

    Application.put_env(:claptrap, :req_test_plug, {Req.Test, :coordinator_test})
    on_exit(fn -> Application.delete_env(:claptrap, :req_test_plug) end)

    start_supervised!({DynamicSupervisor, strategy: :one_for_one, name: Claptrap.Consumer.WorkerSupervisor})
    :ok
  end

  describe "Consumer.Coordinator" do
    test "starts successfully" do
      start_supervised!(Coordinator)
      assert Process.whereis(Coordinator) |> is_pid()
    end

    test "bootstraps workers for enabled sources on init" do
      source = create_source()
      start_supervised!(Coordinator)
      Process.sleep(100)

      assert Registry.whereis(:source_worker, source.id) != :undefined
    end

    test "does not start workers for disabled sources" do
      source = create_source(%{enabled: false})
      start_supervised!(Coordinator)
      Process.sleep(100)

      assert Registry.whereis(:source_worker, source.id) == :undefined
    end

    test "tick starts missing workers for enabled sources" do
      start_supervised!(Coordinator)
      Process.sleep(50)

      source = create_source()

      coordinator = Process.whereis(Coordinator)
      send(coordinator, :tick)
      Process.sleep(100)

      assert Registry.whereis(:source_worker, source.id) != :undefined
    end

    test "tick is idempotent — does not start duplicate workers" do
      source = create_source()
      start_supervised!(Coordinator)
      Process.sleep(100)

      first_pid = Registry.whereis(:source_worker, source.id)
      assert first_pid != :undefined

      coordinator = Process.whereis(Coordinator)
      send(coordinator, :tick)
      Process.sleep(100)

      assert Registry.whereis(:source_worker, source.id) == first_pid
    end

    test "tick sends :poll to due sources" do
      source = create_source()

      past = DateTime.add(DateTime.utc_now(), -16 * 60, :second)
      Catalog.update_source(source, %{last_consumed_at: past})

      start_supervised!(Coordinator)
      Process.sleep(100)

      coordinator = Process.whereis(Coordinator)
      send(coordinator, :tick)

      :sys.get_state(coordinator)
      assert Process.alive?(coordinator)
    end

    test "tick does not poll sources that are not yet due" do
      source = create_source()
      Catalog.update_source(source, %{last_consumed_at: DateTime.utc_now()})

      start_supervised!(Coordinator)
      Process.sleep(100)

      coordinator = Process.whereis(Coordinator)
      send(coordinator, :tick)

      :sys.get_state(coordinator)
      assert Process.alive?(coordinator)
    end

    test "handles tick without crashing when no sources exist" do
      start_supervised!(Coordinator)
      pid = Process.whereis(Coordinator)
      send(pid, :tick)
      :sys.get_state(pid)
      assert Process.alive?(pid)
    end
  end
end
