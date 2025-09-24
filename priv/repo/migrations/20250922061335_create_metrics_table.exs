defmodule ElixirMetrics.Repo.Migrations.CreateMetricsTable do
  use Ecto.Migration

  def change do
    create table(:metrics) do
      add :name, :string, null: false
      add :value, :float, null: false
      add :tags, :map, default: %{}
      add :metadata, :map, default: %{}
      add :timestamp, :utc_datetime, null: false
      add :source, :string

      timestamps()
    end

    create index(:metrics, [:name])
    create index(:metrics, [:timestamp])
    create index(:metrics, [:source])
  end
end