defmodule Claptrap.Repo.Migrations.CreateSinks do
  use Ecto.Migration

  def change do
    create table(:sinks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string, null: false
      add :name, :string, null: false
      add :config, :map, null: false
      add :credentials, :map
      add :enabled, :boolean, null: false, default: true
      timestamps(type: :utc_datetime_usec)
    end
  end
end
