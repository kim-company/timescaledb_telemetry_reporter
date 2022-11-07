defmodule TimescaleDB.Exporter.Repo.Migrations.AddEventsTable do
  use Ecto.Migration

  def up do
    create table(:telemetry_events, primary_key: false) do
      add :time, :utc_datetime_usec, null: false
      add :namespace, :string, null: false
      add :label, :string, null: false
      add :prefix, :string, null: false
      add :measurement, :map, null: false
      add :metadata, :map, null: false
   end
  
    execute("SELECT create_hypertable('telemetry_events', 'time')")
  end
  
  def down do
    drop(table(:telemetry_events))
  end
end
