defmodule Claptrap.Schemas.Source do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sources" do
    field :type, :string
    field :name, :string
    field :config, :map
    field :credentials, :map
    field :enabled, :boolean, default: true
    field :last_consumed_at, :utc_datetime_usec
    field :tags, {:array, :string}, default: []

    has_many :entries, Claptrap.Schemas.Entry

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(source, attrs) do
    source
    |> cast(attrs, [:type, :name, :config, :credentials, :enabled, :last_consumed_at, :tags])
    |> validate_required([:type, :name, :config])
    |> validate_length(:type, min: 1)
    |> validate_length(:name, min: 1)
  end
end
