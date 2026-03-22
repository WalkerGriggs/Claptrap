defmodule Claptrap.Catalog.Source do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          type: String.t() | nil,
          name: String.t() | nil,
          config: map() | nil,
          credentials: map() | nil,
          enabled: boolean() | nil,
          last_consumed_at: DateTime.t() | nil,
          tags: [String.t()] | nil
        }

  schema "sources" do
    field :type, :string
    field :name, :string
    field :config, :map
    field :credentials, :map
    field :enabled, :boolean, default: true
    field :last_consumed_at, :utc_datetime_usec
    field :tags, {:array, :string}, default: []

    has_many :entries, Claptrap.Catalog.Entry

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
