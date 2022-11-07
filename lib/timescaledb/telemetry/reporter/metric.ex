defmodule TimescaleDB.Telemetry.Reporter.Metric do
TimescaleDB.Telemetry.Metrics
  use Ecto.Schema
  
  @primary_key false

  schema "telemetry_metrics" do
    field :time, :utc_datetime_usec
    field :event_name, :string
    field :metric, :string
    field :measurement, :integer
    field :unit, :string
    field :tags, :map
  end
end
