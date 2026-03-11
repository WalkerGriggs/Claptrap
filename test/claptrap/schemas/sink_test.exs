defmodule Claptrap.Schemas.SinkTest do
  use Claptrap.DataCase, async: true

  alias Claptrap.Schemas.Sink

  @valid_attrs %{
    type: "webhook",
    name: "Test Sink",
    config: %{"url" => "https://example.com/hook"}
  }

  describe "changeset/2" do
    test "valid attributes" do
      changeset = Sink.changeset(%Sink{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires type" do
      changeset = Sink.changeset(%Sink{}, Map.delete(@valid_attrs, :type))
      assert %{type: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires name" do
      changeset = Sink.changeset(%Sink{}, Map.delete(@valid_attrs, :name))
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires config" do
      changeset = Sink.changeset(%Sink{}, Map.delete(@valid_attrs, :config))
      assert %{config: ["can't be blank"]} = errors_on(changeset)
    end

    test "type must not be empty string" do
      changeset = Sink.changeset(%Sink{}, %{@valid_attrs | type: ""})
      assert %{type: [_]} = errors_on(changeset)
    end

    test "name must not be empty string" do
      changeset = Sink.changeset(%Sink{}, %{@valid_attrs | name: ""})
      assert %{name: [_]} = errors_on(changeset)
    end

    test "optional fields are accepted" do
      attrs = Map.merge(@valid_attrs, %{credentials: %{"token" => "abc"}, enabled: false})
      changeset = Sink.changeset(%Sink{}, attrs)
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
