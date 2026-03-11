defmodule Claptrap.Schemas.Subscription do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "subscriptions" do
    field(:tags, {:array, :string}, default: [])

    belongs_to(:sink, Claptrap.Schemas.Sink)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:sink_id, :tags])
    |> validate_required([:sink_id])
    |> foreign_key_constraint(:sink_id)
  end
end
