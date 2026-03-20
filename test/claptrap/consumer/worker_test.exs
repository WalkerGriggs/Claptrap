defmodule Claptrap.Consumer.WorkerTest do
  use Claptrap.DataCase, async: false

  @moduletag :integration
  @moduletag capture_log: true

  import ExUnit.CaptureLog
  import Plug.Conn

  alias Claptrap.Catalog
  alias Claptrap.Consumer.Adapters.RSS
  alias Claptrap.Consumer.Worker
  alias Claptrap.PubSub
  alias Ecto.Adapters.SQL.Sandbox

  defmodule TestAdapter do
    @behaviour Claptrap.Consumer.Adapter

    @impl true
    def mode, do: :pull

    @impl true
    def validate_config(_config), do: :ok

    @impl true
    def fetch(source) do
      config = source.config || %{}
      {:ok, Map.get(config, :test_items, Map.get(config, "test_items", []))}
    end

    @impl true
    def ingest(_source, _input), do: {:error, :unsupported}
  end

  @source_attrs %{type: "rss", name: "Feed", config: %{"url" => "https://example.com/feed.xml"}}

  setup do
    Req.Test.set_req_test_to_shared()
    Req.Test.verify_on_exit!()

    previous_options = Application.get_env(:claptrap, :rss_req_options, [])
    Application.put_env(:claptrap, :rss_req_options, plug: {Req.Test, RSS})

    on_exit(fn -> Application.put_env(:claptrap, :rss_req_options, previous_options) end)

    :ok
  end

  test "successful poll creates entries, broadcasts, and updates last_consumed_at", %{
    sandbox_owner: sandbox_owner
  } do
    owner = self()
    {:ok, source} = Catalog.create_source(@source_attrs)
    source_id = source.id
    PubSub.subscribe(PubSub.topic_entries_new())

    Req.Test.stub(RSS, fn conn ->
      send(owner, :fetched)
      send_resp(conn, 200, rss_feed())
    end)

    _worker_pid = start_worker!(source.id, sandbox_owner, poll_interval: :timer.hours(1))

    assert :ok = Worker.poll(source.id)
    assert_receive :fetched
    assert_receive {:entries_ingested, ^source_id, [entry]}

    assert entry.title == "First post"
    assert [%{external_id: "guid-1"}] = Catalog.list_entries(source_id: source.id)
    assert %DateTime{} = Catalog.get_source!(source.id).last_consumed_at
  end

  test "polling the same feed twice does not create duplicate entries", %{
    sandbox_owner: sandbox_owner
  } do
    owner = self()
    {:ok, source} = Catalog.create_source(@source_attrs)

    Req.Test.stub(RSS, fn conn ->
      send(owner, :fetched)
      send_resp(conn, 200, rss_feed())
    end)

    _worker_pid = start_worker!(source.id, sandbox_owner, poll_interval: :timer.hours(1))

    assert :ok = Worker.poll(source.id)
    assert_receive :fetched
    assert_eventually(fn -> length(Catalog.list_entries(source_id: source.id)) == 1 end)

    assert :ok = Worker.poll(source.id)
    assert_receive :fetched
    assert_eventually(fn -> length(Catalog.list_entries(source_id: source.id)) == 1 end)
  end

  @tag capture_log: true
  test "retries a transient failure and succeeds on the next attempt", %{
    sandbox_owner: sandbox_owner
  } do
    owner = self()
    {:ok, source} = Catalog.create_source(@source_attrs)
    source_id = source.id
    PubSub.subscribe(PubSub.topic_entries_new())

    Req.Test.expect(RSS, fn conn ->
      send(owner, :first_attempt)
      send_resp(conn, 500, "boom")
    end)

    Req.Test.expect(RSS, fn conn ->
      send(owner, :second_attempt)
      send_resp(conn, 200, rss_feed())
    end)

    _worker_pid =
      start_worker!(source.id, sandbox_owner,
        poll_interval: :timer.hours(1),
        retry_base_interval: 1,
        retry_jitter: 0,
        max_retry_delay: 5
      )

    assert :ok = Worker.poll(source.id)
    assert_receive :first_attempt
    assert_receive :second_attempt
    assert_receive {:entries_ingested, ^source_id, [_entry]}
  end

  test "logs exhausted retries and resumes the normal poll schedule", %{
    sandbox_owner: sandbox_owner
  } do
    owner = self()
    {:ok, source} = Catalog.create_source(@source_attrs)
    source_id = source.id
    PubSub.subscribe(PubSub.topic_entries_new())

    Req.Test.expect(RSS, 2, fn conn ->
      send(owner, :failed_attempt)
      send_resp(conn, 500, "boom")
    end)

    Req.Test.expect(RSS, fn conn ->
      send(owner, :recovered_attempt)
      send_resp(conn, 200, rss_feed())
    end)

    log =
      capture_log(fn ->
        _worker_pid =
          start_worker!(source.id, sandbox_owner,
            poll_interval: 10,
            max_retries: 1,
            retry_base_interval: 1,
            retry_jitter: 0,
            max_retry_delay: 5
          )

        assert :ok = Worker.poll(source.id)
        assert_receive :failed_attempt
        assert_receive :failed_attempt
        assert_receive :recovered_attempt
        assert_receive {:entries_ingested, ^source_id, [_entry]}
      end)

    assert log =~ "exhausted retries"
  end

  test "crashes on invalid source config" do
    {:ok, source} = Catalog.create_source(%{type: "rss", name: "Broken Feed", config: %{}})
    old_flag = Process.flag(:trap_exit, true)
    on_exit(fn -> Process.flag(:trap_exit, old_flag) end)

    assert {:error, {%ArgumentError{message: message}, _stacktrace}} =
             Worker.start_link(source_id: source.id, initial_poll_delay: :timer.minutes(5))

    assert message =~ "invalid source config"
  end

  test "skips invalid entries and continues ingesting the rest", %{sandbox_owner: sandbox_owner} do
    {:ok, source} = Catalog.create_source(@source_attrs)

    source_id = source.id
    PubSub.subscribe(PubSub.topic_entries_new())

    worker_pid = start_worker!(source_id, sandbox_owner, poll_interval: :timer.hours(1))

    :sys.replace_state(worker_pid, fn state ->
      %{
        state
        | adapter: TestAdapter,
          source: %{
            state.source
            | config: %{test_items: [%{external_id: "bad-item"}, %{external_id: "good-item", title: "Good"}]}
          }
      }
    end)

    log =
      capture_log(fn ->
        assert :ok = Worker.poll(source_id)

        assert_eventually(fn ->
          match?([%{external_id: "good-item"}], Catalog.list_entries(source_id: source_id))
        end)
      end)

    assert log =~ "failed to persist entry"
    assert Process.alive?(worker_pid)
    assert [%{external_id: "good-item"}] = Catalog.list_entries(source_id: source_id)
  end

  test "ignores unexpected messages", %{sandbox_owner: sandbox_owner} do
    {:ok, source} = Catalog.create_source(@source_attrs)
    worker_pid = start_worker!(source.id, sandbox_owner, poll_interval: :timer.hours(1))

    send(worker_pid, :unexpected)
    Process.sleep(20)

    assert Process.alive?(worker_pid)
  end

  test "manual polls do not create overlapping scheduled poll chains", %{sandbox_owner: sandbox_owner} do
    owner = self()
    {:ok, source} = Catalog.create_source(@source_attrs)

    Req.Test.stub(RSS, fn conn ->
      send(owner, :fetched)
      send_resp(conn, 200, rss_feed())
    end)

    _worker_pid =
      start_worker!(source.id, sandbox_owner,
        poll_interval: :timer.minutes(5),
        initial_poll_delay: 200
      )

    assert :ok = Worker.poll(source.id)
    assert_receive :fetched
    refute_receive :fetched, 300
  end

  defp start_worker!(source_id, sandbox_owner, opts) do
    {:ok, pid} =
      start_supervised({Worker, Keyword.merge([source_id: source_id, initial_poll_delay: :timer.minutes(5)], opts)})

    Sandbox.allow(Claptrap.Repo, sandbox_owner, pid)
    Req.Test.allow(RSS, self(), pid)
    pid
  end

  defp assert_eventually(fun, attempts \\ 20)

  defp assert_eventually(fun, attempts) when attempts > 0 do
    if fun.() do
      assert true
    else
      Process.sleep(10)
      assert_eventually(fun, attempts - 1)
    end
  end

  defp assert_eventually(_fun, 0), do: flunk("condition was not met")

  defp rss_feed do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>Example Feed</title>
        <item>
          <guid>guid-1</guid>
          <title>First post</title>
          <description>A summary</description>
          <link>https://example.com/posts/1</link>
          <pubDate>Tue, 18 Mar 2026 00:00:00 GMT</pubDate>
          <category>elixir</category>
        </item>
      </channel>
    </rss>
    """
  end
end
