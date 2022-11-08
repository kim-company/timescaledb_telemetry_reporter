defmodule TimescaleDB.Telemetry.Reporter do
  use GenServer

  alias TimescaleDB.Telemetry.Reporter.Sink

  def start_link(opts) do
    server_opts = Keyword.take(opts, [:name])

    mandatory =
      Enum.map([:metrics, :repo], fn key ->
        {key,
         Keyword.get_lazy(opts, key, fn ->
           raise ArgumentError, "#{inspect(key)} option is required by #{inspect(__MODULE__)}"
         end)}
      end)

    extra = Keyword.take(opts, [:namespace, :buffer_cap])

    GenServer.start_link(
      __MODULE__,
      Keyword.merge(extra, mandatory),
      server_opts
    )
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)
    metrics = Keyword.fetch!(opts, :metrics)

    state =
      metrics
      |> Enum.group_by(fn %{event_name: x} -> x end)
      |> Enum.map(fn {event, metrics} ->
        id = {__MODULE__, event, self()}

        {:ok, pid} =
          opts
          |> Keyword.take([:repo, :namespace, :buffer_cap])
          |> Keyword.put(:metrics, metrics)
          |> Keyword.put(:telemetry_label, "#{Sink}")
          |> Sink.start_link()

        :telemetry.attach(id, event, &__MODULE__.handle_event/4, pid)
        %{event: event, pid: pid}
      end)

    {:ok, state}
  end

  @impl true
  def terminate(_, state) do
    state
    |> Enum.map(fn %{event: event, pid: pid} ->
      Sink.flush(pid)
      Sink.stop(pid)
      event
    end)
    |> Enum.map(fn event ->
      :telemetry.detach({__MODULE__, event, self()})
    end)

    :ok
  end

  def handle_event(event_name, measurements, metadata, pid) do
    :ok = Sink.handle(pid, event_name, measurements, metadata)
  end
end
