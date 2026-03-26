defmodule Claptrap.Catalog.Artifact do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "artifacts" do
    field :format, :string
    field :content, :string
    field :content_type, :string
    field :byte_size, :integer
    field :extractor, :string
    field :metadata, :map

    belongs_to :entry, Claptrap.Catalog.Entry

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(artifact, attrs) do
    artifact
    |> cast(attrs, [:entry_id, :format, :content, :content_type, :byte_size, :extractor, :metadata])
    |> validate_required([:entry_id, :format, :extractor])
    |> validate_inclusion(:format, ["markdown", "html", "pdf"])
    |> validate_length(:extractor, min: 1)
    |> foreign_key_constraint(:entry_id)
    |> unique_constraint([:entry_id, :format])
  end
end
