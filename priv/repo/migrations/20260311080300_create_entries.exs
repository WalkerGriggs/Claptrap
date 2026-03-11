defmodule Claptrap.Repo.Migrations.CreateEntries do
  use Ecto.Migration

  def change do
    create table(:entries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :source_id, references(:sources, on_delete: :delete_all, type: :binary_id), null: false
      add :external_id, :string, null: false
      add :title, :string, null: false
      add :summary, :string
      add :url, :string
      add :author, :string
      add :published_at, :utc_datetime_usec
      add :status, :string, null: false
      add :metadata, :map
      add :tags, {:array, :string}, null: false, default: []
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:entries, [:external_id, :source_id])
    create index(:entries, [:source_id])
  end
end
