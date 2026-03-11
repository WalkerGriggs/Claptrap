defmodule Claptrap.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    create table(:subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :sink_id, references(:sinks, on_delete: :delete_all, type: :binary_id), null: false
      add :tags, {:array, :string}, null: false, default: []
      timestamps(type: :utc_datetime_usec)
    end

    create index(:subscriptions, [:sink_id])
    create index(:subscriptions, [:tags], using: :gin)
  end
end
