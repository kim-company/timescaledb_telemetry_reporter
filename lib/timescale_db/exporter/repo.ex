defmodule TimescaleDB.Exporter.Repo do
  use Ecto.Repo,
    otp_app: :timescale_db_exporter,
    adapter: Ecto.Adapters.Postgres
end
