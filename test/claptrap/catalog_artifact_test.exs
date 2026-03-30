defmodule Claptrap.CatalogArtifactTest do
  use Claptrap.DataCase, async: true

  @moduletag :integration
  @moduletag capture_log: true

  alias Claptrap.Catalog

  @source_attrs %{type: "rss", name: "Feed", config: %{"url" => "https://example.com/feed"}}

  defp create_entry(_context) do
    {:ok, source} = Catalog.create_source(@source_attrs)

    {:ok, entry} =
      Catalog.create_entry(%{
        source_id: source.id,
        external_id: "ext-1",
        title: "Title",
        status: "unread"
      })

    %{source: source, entry: entry}
  end

  defp artifact_attrs(entry) do
    %{
      entry_id: entry.id,
      format: "markdown",
      content: "# Hello",
      content_type: "text/markdown",
      byte_size: 7,
      extractor: "readability",
      metadata: %{"version" => 1}
    }
  end

  describe "create_artifact/1" do
    setup [:create_entry]

    test "creates an artifact with valid attrs", %{entry: entry} do
      assert {:ok, artifact} = Catalog.create_artifact(artifact_attrs(entry))
      assert artifact.format == "markdown"
      assert artifact.content == "# Hello"
      assert artifact.extractor == "readability"
      assert artifact.entry_id == entry.id
    end

    test "returns error with missing required fields" do
      assert {:error, changeset} = Catalog.create_artifact(%{})
      errors = Claptrap.DataCase.errors_on(changeset)
      assert Map.has_key?(errors, :entry_id)
      assert Map.has_key?(errors, :format)
      assert Map.has_key?(errors, :extractor)
    end

    test "upsert idempotency: same entry_id + format updates existing row", %{entry: entry} do
      attrs = artifact_attrs(entry)
      assert {:ok, first} = Catalog.create_artifact(attrs)

      updated_attrs = %{attrs | content: "# Updated", byte_size: 9}
      assert {:ok, second} = Catalog.create_artifact(updated_attrs)

      assert first.id == second.id
      assert second.content == "# Updated"
      assert second.byte_size == 9
      assert length(Catalog.list_artifacts(entry_id: entry.id)) == 1
    end
  end

  describe "list_artifacts/1" do
    setup [:create_entry]

    test "returns only artifacts for the given entry", %{entry: entry} do
      {:ok, _} = Catalog.create_artifact(artifact_attrs(entry))

      {:ok, other_entry} =
        Catalog.create_entry(%{
          source_id: entry.source_id,
          external_id: "ext-2",
          title: "Other",
          status: "unread"
        })

      {:ok, _} =
        Catalog.create_artifact(%{
          entry_id: other_entry.id,
          format: "html",
          extractor: "readability",
          content: "<p>Hi</p>"
        })

      artifacts = Catalog.list_artifacts(entry_id: entry.id)
      assert length(artifacts) == 1
      assert hd(artifacts).entry_id == entry.id
    end

    test "returns all artifacts when no filter", %{entry: entry} do
      {:ok, _} = Catalog.create_artifact(artifact_attrs(entry))
      assert length(Catalog.list_artifacts()) == 1
    end

    test "paginates results", %{entry: entry} do
      for fmt <- ["markdown", "html", "pdf"] do
        {:ok, _} = Catalog.create_artifact(%{artifact_attrs(entry) | format: fmt})
      end

      page1 = Catalog.list_artifacts(paginate: true, limit: 2)
      assert length(page1.entries) == 2
      assert page1.metadata.after

      page2 = Catalog.list_artifacts(paginate: true, limit: 2, after: page1.metadata.after)
      assert length(page2.entries) == 1
    end

    test "paginates with entry_id filter", %{entry: entry} do
      for fmt <- ["markdown", "html"] do
        {:ok, _} = Catalog.create_artifact(%{artifact_attrs(entry) | format: fmt})
      end

      {:ok, other_entry} =
        Catalog.create_entry(%{
          source_id: entry.source_id,
          external_id: "ext-other",
          title: "Other",
          status: "unread"
        })

      {:ok, _} =
        Catalog.create_artifact(%{
          entry_id: other_entry.id,
          format: "pdf",
          extractor: "readability"
        })

      page = Catalog.list_artifacts(paginate: true, limit: 10, entry_id: entry.id)
      assert length(page.entries) == 2
      assert Enum.all?(page.entries, &(&1.entry_id == entry.id))
    end
  end

  describe "get_artifact!/1" do
    setup [:create_entry]

    test "returns the artifact", %{entry: entry} do
      {:ok, artifact} = Catalog.create_artifact(artifact_attrs(entry))
      assert Catalog.get_artifact!(artifact.id).id == artifact.id
    end

    test "raises on nonexistent ID" do
      assert_raise Ecto.NoResultsError, fn ->
        Catalog.get_artifact!(Ecto.UUID.generate())
      end
    end
  end

  describe "delete_artifact/1" do
    setup [:create_entry]

    test "removes the artifact", %{entry: entry} do
      {:ok, artifact} = Catalog.create_artifact(artifact_attrs(entry))
      assert {:ok, _} = Catalog.delete_artifact(artifact)
      assert Catalog.list_artifacts(entry_id: entry.id) == []
    end
  end

  describe "cascade delete" do
    setup [:create_entry]

    test "deleting a source cascades to remove its entries' artifacts", %{source: source, entry: entry} do
      {:ok, _} = Catalog.create_artifact(artifact_attrs(entry))
      assert length(Catalog.list_artifacts(entry_id: entry.id)) == 1

      Catalog.delete_source(source)

      assert Catalog.list_artifacts() == []
    end
  end
end
