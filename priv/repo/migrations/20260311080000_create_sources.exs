defmodule Claptrap.Repo.Migrations.CreateSources do
  use Ecto.Migration

  def change do
    create table(:sources, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string, null: false
      add :name, :string, null: false
      add :config, :map, null: false
      add :credentials, :map
      add :enabled, :boolean, null: false, default: true
      add :last_consumed_at, :utc_datetime_usec
      add :tags, {:array, :string}, null: false, default: []
      timestamps(type: :utc_datetime_usec)
    end
  end
end
