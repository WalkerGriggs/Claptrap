defmodule Claptrap.Catalog.Sink do
  @moduledoc """
  Ecto schema for configured downstream delivery targets.
  
  A sink stores destination configuration (`type`, `config`), optional
  credentials, and an `enabled` flag. Subscriptions are attached to sinks and
  control which entries are routed to each destination.
  
  The changeset requires `type`, `name`, and `config`, and validates that `type`
  and `name` are non-empty.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sinks" do
    field :type, :string
    field :name, :string
    field :config, :map
    field :credentials, :map
    field :enabled, :boolean, default: true

    has_many :subscriptions, Claptrap.Catalog.Subscription

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(sink, attrs) do
    sink
    |> cast(attrs, [:type, :name, :config, :credentials, :enabled])
    |> validate_required([:type, :name, :config])
    |> validate_length(:type, min: 1)
    |> validate_length(:name, min: 1)
  end
end
