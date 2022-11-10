defmodule TimescaleDB.Telemetry.Reporter.Migrations do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE")

    create table(:telemetry_metrics, primary_key: false) do
      add(:time, :utc_datetime_usec, null: false)
      add(:event_name, :string, null: false)
      add(:metric, :string, null: false)
      add(:measurement, :bigint, null: false)
      add(:unit, :string, null: false)
      add(:tags, :map, null: false)
    end

    execute("SELECT create_hypertable('telemetry_metrics', 'time')")
  end

  def down do
    drop(table(:telemetry_metrics))

    execute("DROP EXTENSION IF EXISTS timescaledb CASCADE")
  end
end
