defmodule Claptrap.Extractor.IntegrationTest do
  use Claptrap.DataCase, async: false

  @moduletag :integration
  @moduletag capture_log: true

  alias Claptrap.Catalog
  alias Claptrap.PubSub, as: PS

  @source_attrs %{type: "rss", name: "Feed", config: %{"url" => "https://example.com/feed"}}

  defmodule TestAdapter do
    @behaviour Claptrap.Extractor.Adapter

    def extract(url, format, _opts) do
      {:ok,
       %{
         content: "Extracted #{format} from #{url}",
         content_type: content_type(format),
         metadata: %{"source" => "test"}
       }}
    end

    def supported_formats, do: ["markdown", "html"]

    defp content_type("markdown"), do: "text/markdown"
    defp content_type("html"), do: "text/html"
    defp content_type(_), do: "application/octet-stream"
  end

  setup do
    previous_extraction = Application.get_env(:claptrap, :extraction)

    Application.put_env(:claptrap, :extraction, %{
      formats: ["markdown"],
      adapters: %{"markdown" => TestAdapter}
    })

    # Restart the supervisor so Router picks up the new config
    Supervisor.terminate_child(Claptrap.Supervisor, Claptrap.Extractor.Supervisor)
    Process.sleep(20)
    Supervisor.restart_child(Claptrap.Supervisor, Claptrap.Extractor.Supervisor)
    Process.sleep(20)

    on_exit(fn ->
      if previous_extraction do
        Application.put_env(:claptrap, :extraction, previous_extraction)
      else
        Application.delete_env(:claptrap, :extraction)
      end

      ExUnit.CaptureLog.capture_log(fn ->
        Supervisor.terminate_child(Claptrap.Supervisor, Claptrap.Extractor.Supervisor)
        Process.sleep(20)
        Supervisor.restart_child(Claptrap.Supervisor, Claptrap.Extractor.Supervisor)
      end)
    end)

    :ok
  end

  describe "full pipeline: PubSub -> artifact in DB" do
    test "creates artifact from PubSub broadcast" do
      {:ok, source} = Catalog.create_source(@source_attrs)

      {:ok, entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "ext-int-1",
          title: "Integration Test",
          url: "https://example.com/article",
          status: "unread"
        })

      PS.broadcast!(PS.topic_entries_new(), {:entries_ingested, source.id, [entry]})
      Process.sleep(500)

      [artifact] = Catalog.list_artifacts(entry_id: entry.id)
      assert artifact.entry_id == entry.id
      assert artifact.format == "markdown"
      assert artifact.content == "Extracted markdown from https://example.com/article"
      assert artifact.content_type == "text/markdown"
      assert artifact.extractor == "testadapter"
      assert artifact.byte_size == byte_size(artifact.content)
    end
  end

  describe "entries without URLs produce no artifacts" do
    test "nil URL entry creates no artifact" do
      {:ok, source} = Catalog.create_source(@source_attrs)

      {:ok, entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "ext-int-2",
          title: "No URL",
          status: "unread"
        })

      PS.broadcast!(PS.topic_entries_new(), {:entries_ingested, source.id, [entry]})
      Process.sleep(500)

      assert Catalog.list_artifacts(entry_id: entry.id) == []
    end
  end

  describe "re-broadcast upserts, not duplicates" do
    test "broadcasting twice produces one artifact row" do
      {:ok, source} = Catalog.create_source(@source_attrs)

      {:ok, entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "ext-int-3",
          title: "Upsert Test",
          url: "https://example.com/upsert",
          status: "unread"
        })

      PS.broadcast!(PS.topic_entries_new(), {:entries_ingested, source.id, [entry]})
      Process.sleep(500)

      PS.broadcast!(PS.topic_entries_new(), {:entries_ingested, source.id, [entry]})
      Process.sleep(500)

      artifacts = Catalog.list_artifacts(entry_id: entry.id)
      assert length(artifacts) == 1
    end
  end

  describe "extraction does not interfere with PubSub fan-out" do
    test "test process and Router both receive the event" do
      PS.subscribe(PS.topic_entries_new())

      {:ok, source} = Catalog.create_source(@source_attrs)

      {:ok, entry} =
        Catalog.create_entry(%{
          source_id: source.id,
          external_id: "ext-int-4",
          title: "Fan-out",
          url: "https://example.com/fanout",
          status: "unread"
        })

      source_id = source.id
      PS.broadcast!(PS.topic_entries_new(), {:entries_ingested, source.id, [entry]})

      assert_receive {:entries_ingested, ^source_id, [^entry]}, 1_000

      Process.sleep(500)

      [artifact] = Catalog.list_artifacts(entry_id: entry.id)
      assert artifact.format == "markdown"
    end
  end
end
