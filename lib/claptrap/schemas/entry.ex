defmodule Claptrap.Schemas.Entry do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "entries" do
    field :external_id, :string
    field :title, :string
    field :summary, :string
    field :url, :string
    field :author, :string
    field :published_at, :utc_datetime_usec
    field :status, :string
    field :metadata, :map
    field :tags, {:array, :string}, default: []

    belongs_to :source, Claptrap.Schemas.Source

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :source_id,
      :external_id,
      :title,
      :summary,
      :url,
      :author,
      :published_at,
      :status,
      :metadata,
      :tags
    ])
    |> validate_required([:source_id, :external_id, :title, :status])
    |> validate_inclusion(:status, ["unread", "in_progress", "read", "archived"])
    |> unique_constraint([:external_id, :source_id])
  end
end
