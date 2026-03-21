defmodule Claptrap.Schemas.SourceTest do
  use Claptrap.DataCase, async: true

  @moduletag :integration
  @moduletag capture_log: true

  alias Claptrap.Schemas.Source

  @valid_attrs %{
    type: "rss",
    name: "Test Feed",
    config: %{"url" => "https://example.com/feed"}
  }

  describe "changeset/2" do
    test "valid attributes" do
      changeset = Source.changeset(%Source{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires type" do
      changeset = Source.changeset(%Source{}, Map.delete(@valid_attrs, :type))
      assert %{type: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires name" do
      changeset = Source.changeset(%Source{}, Map.delete(@valid_attrs, :name))
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires config" do
      changeset = Source.changeset(%Source{}, Map.delete(@valid_attrs, :config))
      assert %{config: ["can't be blank"]} = errors_on(changeset)
    end

    test "type must not be empty string" do
      changeset = Source.changeset(%Source{}, %{@valid_attrs | type: ""})
      assert %{type: [_]} = errors_on(changeset)
    end

    test "name must not be empty string" do
      changeset = Source.changeset(%Source{}, %{@valid_attrs | name: ""})
      assert %{name: [_]} = errors_on(changeset)
    end

    test "optional fields are accepted" do
      attrs =
        Map.merge(@valid_attrs, %{
          credentials: %{"key" => "secret"},
          enabled: false,
          tags: ["elixir", "news"]
        })

      changeset = Source.changeset(%Source{}, attrs)
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
