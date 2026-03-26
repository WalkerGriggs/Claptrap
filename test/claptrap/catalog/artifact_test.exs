defmodule Claptrap.Catalog.ArtifactTest do
  use Claptrap.DataCase, async: true

  @moduletag :integration
  @moduletag capture_log: true

  alias Claptrap.Catalog.Artifact

  @valid_attrs %{
    entry_id: "00000000-0000-0000-0000-000000000001",
    format: "markdown",
    extractor: "firecrawl"
  }

  describe "changeset/2" do
    test "valid attributes" do
      changeset = Artifact.changeset(%Artifact{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires entry_id" do
      changeset = Artifact.changeset(%Artifact{}, Map.delete(@valid_attrs, :entry_id))
      assert %{entry_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires format" do
      changeset = Artifact.changeset(%Artifact{}, Map.delete(@valid_attrs, :format))
      assert %{format: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires extractor" do
      changeset = Artifact.changeset(%Artifact{}, Map.delete(@valid_attrs, :extractor))
      assert %{extractor: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects invalid format" do
      changeset = Artifact.changeset(%Artifact{}, %{@valid_attrs | format: "invalid"})
      assert %{format: [_]} = errors_on(changeset)
    end

    test "accepts all valid formats" do
      for format <- ["markdown", "html", "pdf"] do
        changeset = Artifact.changeset(%Artifact{}, %{@valid_attrs | format: format})
        assert changeset.valid?, "expected format #{format} to be valid"
      end
    end

    test "optional fields are accepted" do
      attrs =
        Map.merge(@valid_attrs, %{
          content: "# Hello World",
          content_type: "text/markdown",
          byte_size: 1024,
          metadata: %{"key" => "value"}
        })

      changeset = Artifact.changeset(%Artifact{}, attrs)
      assert changeset.valid?
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
