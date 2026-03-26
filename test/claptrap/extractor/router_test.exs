defmodule Claptrap.Extractor.RouterTest do
  use Claptrap.DataCase, async: false

  @moduletag :integration
  @moduletag capture_log: true

  alias Claptrap.Catalog
  alias Claptrap.Extractor.Router
  alias Claptrap.PubSub, as: PS

  @source_attrs %{type: "rss", name: "Feed", config: %{"url" => "https://example.com/feed"}}

  defmodule TestAdapter do
    @behaviour Claptrap.Extractor.Adapter

    def extract(url, format, _opts) do
      {:ok,
       %{
         content: "Extracted #{format} from #{url}",
         content_type: "text/markdown",
         metadata: %{}
       }}
    end

    def supported_formats, do: ["markdown"]
  end

  setup do
    Supervisor.terminate_child(Claptrap.Supervisor, Claptrap.Extractor.Supervisor)
    Process.sleep(20)

    previous_extraction = Application.get_env(:claptrap, :extraction)

    Application.put_env(:claptrap, :extraction, %{
      formats: ["markdown"],
      adapters: %{"markdown" => TestAdapter}
    })

    start_supervised!({Task.Supervisor, name: Claptrap.Extractor.TaskSupervisor})

    on_exit(fn ->
      if previous_extraction do
        Application.put_env(:claptrap, :extraction, previous_extraction)
      else
        Application.delete_env(:claptrap, :extraction)
      end

      ExUnit.CaptureLog.capture_log(fn ->
        Supervisor.restart_child(Claptrap.Supervisor, Claptrap.Extractor.Supervisor)
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
    test "receives entries_ingested and spawns tasks" do
      {:ok, source} = Catalog.create_source(@source_attrs)

      {:ok, entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "ext-1",
          title: "Title",
          url: "https://example.com/article",
          status: "unread"
        })

      start_supervised!(Router)

      PS.broadcast!(PS.topic_entries_new(), {:entries_ingested, source.id, [entry]})

      # Wait for async task to finish
      Process.sleep(200)

      [artifact] = Catalog.list_artifacts(entry_id: entry.id)
      assert artifact.format == "markdown"
      assert artifact.content =~ "example.com/article"
    end
  end

  describe "skips entries without URLs" do
    test "entries with nil URL produce no artifacts" do
      {:ok, source} = Catalog.create_source(@source_attrs)

      {:ok, entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "ext-2",
          title: "No URL",
          status: "unread"
        })

      start_supervised!(Router)

      PS.broadcast!(PS.topic_entries_new(), {:entries_ingested, source.id, [entry]})
      Process.sleep(200)

      assert Catalog.list_artifacts(entry_id: entry.id) == []
    end
  end

  describe "extraction disabled" do
    test "no-ops when formats list is empty" do
      Application.put_env(:claptrap, :extraction, %{formats: [], adapters: %{}})

      {:ok, source} = Catalog.create_source(@source_attrs)

      {:ok, entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "ext-3",
          title: "Title",
          url: "https://example.com/article",
          status: "unread"
        })

      start_supervised!(Router)

      PS.broadcast!(PS.topic_entries_new(), {:entries_ingested, source.id, [entry]})
      Process.sleep(200)

      assert Catalog.list_artifacts(entry_id: entry.id) == []
    end
  end

  describe "handle_info/2" do
    test "handles unexpected messages gracefully" do
      pid = start_supervised!(Router)
      send(pid, :some_garbage)
      _ = :sys.get_state(pid)
      assert Process.alive?(pid)
    end
  end
end
