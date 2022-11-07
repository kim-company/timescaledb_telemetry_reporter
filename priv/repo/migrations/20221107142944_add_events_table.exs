defmodule TimescaleDB.Telemetry.Reporter.Repo.Migrations.AddEventsTable do
  use Ecto.Migration

  def up do
    create table(:telemetry_events, primary_key: false) do
      add :time, :utc_datetime_usec, null: false
      add :event_name, :string, null: false
      add :metric, :string, null: false
      add :measurement, :integer, null: false
      add :unit, :string, null: false 
      add :tags, :map, null: false
   end
  
    execute("SELECT create_hypertable('telemetry_events', 'time')")
  end
  
  def down do
    drop(table(:telemetry_events))
  end
end
