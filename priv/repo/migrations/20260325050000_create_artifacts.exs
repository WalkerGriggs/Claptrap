defmodule Claptrap.Repo.Migrations.CreateArtifacts do
  use Ecto.Migration

  def change do
    create table(:artifacts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :entry_id, references(:entries, type: :binary_id, on_delete: :delete_all), null: false
      add :format, :string, null: false
      add :content, :text
      add :content_type, :string
      add :byte_size, :integer
      add :extractor, :string, null: false
      add :metadata, :map
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:artifacts, [:entry_id, :format])
  end
end
