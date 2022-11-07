import Config

config :timescale_db_exporter, TimescaleDB.Exporter.Repo,
  database: "timescale_db_exporter_repo",
  username: "user",
  password: "pass",
  hostname: "100.109.80.31"

config :timescale_db_exporter,
      ecto_repos: [TimescaleDB.Exporter.Repo]
