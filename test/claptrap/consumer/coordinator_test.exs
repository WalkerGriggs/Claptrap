defmodule Claptrap.Consumer.CoordinatorTest do
  use Claptrap.DataCase, async: false

  import ExUnit.CaptureLog
  import Plug.Conn

  alias Claptrap.Catalog
  alias Claptrap.Consumer.Adapters.RSS
  alias Claptrap.Consumer.Coordinator
  alias Claptrap.Registry

  @source_attrs %{type: "rss", name: "Feed", config: %{"url" => "https://example.com/feed.xml"}}

  setup do
    Req.Test.set_req_test_to_shared()
    Req.Test.verify_on_exit!()

    previous_options = Application.get_env(:claptrap, :rss_req_options, [])
    previous_initial_poll_delay = Application.get_env(:claptrap, :consumer_initial_poll_delay)

    Application.put_env(:claptrap, :rss_req_options, plug: {Req.Test, RSS})
    Application.put_env(:claptrap, :consumer_initial_poll_delay, :timer.minutes(5))

    Req.Test.stub(RSS, fn conn ->
      send_resp(conn, 200, empty_feed())
    end)

    on_exit(fn ->
      Application.put_env(:claptrap, :rss_req_options, previous_options)

      if is_nil(previous_initial_poll_delay) do
        Application.delete_env(:claptrap, :consumer_initial_poll_delay)
      else
        Application.put_env(:claptrap, :consumer_initial_poll_delay, previous_initial_poll_delay)
      end
    end)

    :ok
  end

  describe "Consumer.Coordinator" do
    test "bootstraps workers for enabled sources on init" do
      {:ok, enabled_source} = Catalog.create_source(@source_attrs)
      {:ok, _disabled_source} = Catalog.create_source(Map.put(@source_attrs, :enabled, false))

      restart_consumer_supervisor!()

      assert_eventually(fn ->
        match?(pid when is_pid(pid), Registry.whereis(:source_worker, enabled_source.id))
      end)
    end

    test "tick starts missing workers for enabled sources" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      pid = Process.whereis(Coordinator)

      send(pid, :tick)

      assert_eventually(fn ->
        match?(worker_pid when is_pid(worker_pid), Registry.whereis(:source_worker, source.id))
      end)
    end

    test "does not start workers for disabled sources" do
      {:ok, source} = Catalog.create_source(Map.put(@source_attrs, :enabled, false))
      pid = Process.whereis(Coordinator)

      send(pid, :tick)
      Process.sleep(20)

      assert Registry.whereis(:source_worker, source.id) == :undefined
    end

    test "tick is idempotent and does not start duplicate workers" do
      {:ok, source} = Catalog.create_source(@source_attrs)
      pid = Process.whereis(Coordinator)

      send(pid, :tick)

      first_worker_pid =
        eventually(fn -> Registry.whereis(:source_worker, source.id) end)

      send(pid, :tick)
      Process.sleep(20)

      assert Registry.whereis(:source_worker, source.id) == first_worker_pid
    end

    test "tick logs reconciliation failures and keeps running" do
      pid = Process.whereis(Coordinator)
      original_state = :sys.get_state(pid)

      on_exit(fn -> :sys.replace_state(pid, fn _state -> original_state end) end)

      :sys.replace_state(pid, fn state ->
        Map.put(state, :list_sources_fun, fn _opts -> raise "db temporarily unavailable" end)
      end)

      log =
        capture_log(fn ->
          send(pid, :tick)
          Process.sleep(20)
        end)

      assert log =~ "reconciliation failed"
      assert Process.alive?(pid)
    end

    test "tick logs reconciliation exits and keeps running" do
      pid = Process.whereis(Coordinator)
      original_state = :sys.get_state(pid)

      on_exit(fn -> :sys.replace_state(pid, fn _state -> original_state end) end)

      :sys.replace_state(pid, fn state ->
        Map.put(state, :list_sources_fun, fn _opts -> exit(:worker_supervisor_down) end)
      end)

      log =
        capture_log(fn ->
          send(pid, :tick)
          Process.sleep(20)
        end)

      assert log =~ "reconciliation exited"
      assert Process.alive?(pid)
    end
  end

  defp restart_consumer_supervisor! do
    :ok = Supervisor.terminate_child(Claptrap.Supervisor, Claptrap.Consumer.Supervisor)
    {:ok, _pid} = Supervisor.restart_child(Claptrap.Supervisor, Claptrap.Consumer.Supervisor)
  end

  defp assert_eventually(fun) do
    eventually(fun)
    assert true
  end

  defp eventually(fun, attempts \\ 20)

  defp eventually(fun, attempts) when attempts > 0 do
    case fun.() do
      pid when is_pid(pid) -> pid
      true -> true
      :undefined -> retry(fun, attempts)
      nil -> retry(fun, attempts)
      false -> retry(fun, attempts)
      other -> raise "eventually/2 got unexpected value: #{inspect(other)}"
    end
  end

  defp eventually(_fun, 0), do: flunk("condition was not met")

  defp retry(fun, attempts) do
    Process.sleep(10)
    eventually(fun, attempts - 1)
  end

  defp empty_feed do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>Empty Feed</title>
      </channel>
    </rss>
    """
  end
end
