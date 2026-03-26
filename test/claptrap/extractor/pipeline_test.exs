defmodule Claptrap.Extractor.PipelineTest do
  use Claptrap.DataCase, async: false

  @moduletag :integration
  @moduletag capture_log: true

  alias Claptrap.Catalog
  alias Claptrap.Extractor.Pipeline

  @source_attrs %{type: "rss", name: "Feed", config: %{"url" => "https://example.com/feed"}}

  defmodule SuccessAdapter do
    @behaviour Claptrap.Extractor.Adapter

    def extract(_url, "markdown", _opts) do
      {:ok, %{content: "# Hello", content_type: "text/markdown", metadata: %{"v" => 1}}}
    end

    def extract(_url, "html", _opts) do
      {:ok, %{content: "<h1>Hello</h1>", content_type: "text/html", metadata: %{"v" => 1}}}
    end

    def supported_formats, do: ["markdown", "html"]
  end

  defmodule FailAdapter do
    @behaviour Claptrap.Extractor.Adapter

    def extract(_url, _format, _opts), do: {:error, :boom}
    def supported_formats, do: ["markdown"]
  end

  defmodule CountingAdapter do
    @behaviour Claptrap.Extractor.Adapter

    def extract(_url, _format, opts) do
      counter = opts[:counter]
      count = Agent.get_and_update(counter, &{&1, &1 + 1})

      if count < opts[:fail_count] do
        {:error, :transient}
      else
        {:ok, %{content: "# Recovered", content_type: "text/markdown", metadata: %{}}}
      end
    end

    def supported_formats, do: ["markdown"]
  end

  defp create_entry(_context) do
    {:ok, source} = Catalog.create_source(@source_attrs)

    {:ok, entry} =
      Catalog.create_entry(%{
        source_id: source.id,
        external_id: "ext-1",
        title: "Title",
        url: "https://example.com/article",
        status: "unread"
      })

    %{source: source, entry: entry}
  end

  describe "extract_and_store/3" do
    setup [:create_entry]

    test "single format success creates artifact", %{entry: entry} do
      config = %{adapters: %{"markdown" => SuccessAdapter}}

      assert :ok = Pipeline.extract_and_store(entry, ["markdown"], config)

      [artifact] = Catalog.list_artifacts(entry_id: entry.id)
      assert artifact.format == "markdown"
      assert artifact.content == "# Hello"
      assert artifact.content_type == "text/markdown"
      assert artifact.byte_size == byte_size("# Hello")
      assert artifact.extractor == "successadapter"
    end

    test "multi-format success creates both artifacts", %{entry: entry} do
      config = %{adapters: %{"markdown" => SuccessAdapter, "html" => SuccessAdapter}}

      assert :ok = Pipeline.extract_and_store(entry, ["markdown", "html"], config)

      artifacts = Catalog.list_artifacts(entry_id: entry.id)
      assert length(artifacts) == 2
      formats = Enum.map(artifacts, & &1.format) |> Enum.sort()
      assert formats == ["html", "markdown"]
    end

    test "retry on transient error then succeed", %{entry: entry} do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      config = %{
        adapters: %{"markdown" => CountingAdapter},
        counter: counter,
        fail_count: 2,
        max_attempts: 5,
        base_backoff_ms: 1,
        max_backoff_ms: 10
      }

      assert :ok = Pipeline.extract_and_store(entry, ["markdown"], config)

      [artifact] = Catalog.list_artifacts(entry_id: entry.id)
      assert artifact.content == "# Recovered"

      Agent.stop(counter)
    end

    test "exhaust retries creates no artifact", %{entry: entry} do
      config = %{
        adapters: %{"markdown" => FailAdapter},
        max_attempts: 2,
        base_backoff_ms: 1,
        max_backoff_ms: 10
      }

      assert :ok = Pipeline.extract_and_store(entry, ["markdown"], config)

      assert Catalog.list_artifacts(entry_id: entry.id) == []
    end

    test "entry without URL returns immediately" do
      entry = %{id: Ecto.UUID.generate(), url: nil}
      assert :ok = Pipeline.extract_and_store(entry, ["markdown"], %{adapters: %{}})
    end

    test "idempotent re-extraction upserts", %{entry: entry} do
      config = %{adapters: %{"markdown" => SuccessAdapter}}

      Pipeline.extract_and_store(entry, ["markdown"], config)
      Pipeline.extract_and_store(entry, ["markdown"], config)

      artifacts = Catalog.list_artifacts(entry_id: entry.id)
      assert length(artifacts) == 1
    end

    test "format failure independence", %{entry: entry} do
      config = %{
        adapters: %{"markdown" => FailAdapter, "html" => SuccessAdapter},
        max_attempts: 1,
        base_backoff_ms: 1,
        max_backoff_ms: 10
      }

      assert :ok = Pipeline.extract_and_store(entry, ["markdown", "html"], config)

      artifacts = Catalog.list_artifacts(entry_id: entry.id)
      assert length(artifacts) == 1
      assert hd(artifacts).format == "html"
    end
  end
end
