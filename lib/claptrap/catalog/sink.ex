defmodule Claptrap.Catalog.Sink do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :type, :name, :config, :enabled, :inserted_at, :updated_at]}

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
