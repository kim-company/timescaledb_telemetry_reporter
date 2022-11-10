defmodule TimescaleDB.Telemetry.Reporter do
  use Supervisor, restart: :transient

  alias TimescaleDB.Telemetry.Reporter.{Broadcaster, Sink}

  def start_link(opts) do
    server_opts = Keyword.take(opts, [:name])
    Supervisor.start_link(__MODULE__, opts, server_opts)
  end

  @impl true
  def init(opts) do
    children = [
      {Broadcaster, opts},
      Supervisor.child_spec({Sink, opts}, id: :s1),
      Supervisor.child_spec({Sink, opts}, id: :s2),
      Supervisor.child_spec({Sink, opts}, id: :s3),
      Supervisor.child_spec({Sink, opts}, id: :s4),
      Supervisor.child_spec({Sink, opts}, id: :s5),
      Supervisor.child_spec({Sink, opts}, id: :s6),
      Supervisor.child_spec({Sink, opts}, id: :s7),
      Supervisor.child_spec({Sink, opts}, id: :s8)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
