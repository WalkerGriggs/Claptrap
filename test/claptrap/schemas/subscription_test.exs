defmodule Claptrap.Schemas.SubscriptionTest do
  use Claptrap.DataCase, async: true

  alias Claptrap.Schemas.Subscription

  @valid_attrs %{
    sink_id: "00000000-0000-0000-0000-000000000001",
    tags: ["elixir", "otp"]
  }

  describe "changeset/2" do
    test "valid attributes" do
      changeset = Subscription.changeset(%Subscription{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires sink_id" do
      changeset = Subscription.changeset(%Subscription{}, Map.delete(@valid_attrs, :sink_id))
      assert %{sink_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "defaults tags to empty list" do
      changeset = Subscription.changeset(%Subscription{}, Map.delete(@valid_attrs, :tags))
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
