defmodule Claptrap.Catalog.Subscription do
  @moduledoc """
  Ecto schema for tag-based sink routing rules.

  A subscription belongs to a sink and stores a list of tags. Routing queries
  match entries to subscriptions using array overlap semantics, so any shared
  tag between an entry and a subscription is enough to select that sink.

  The changeset requires `sink_id` and enforces the sink foreign key constraint.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "subscriptions" do
    field(:tags, {:array, :string}, default: [])

    belongs_to(:sink, Claptrap.Catalog.Sink)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:sink_id, :tags])
    |> validate_required([:sink_id])
    |> foreign_key_constraint(:sink_id)
  end
end
