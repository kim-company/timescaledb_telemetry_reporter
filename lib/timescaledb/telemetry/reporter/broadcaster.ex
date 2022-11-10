defmodule TimescaleDB.Telemetry.Reporter.Broadcaster do
  use GenStage
  require Logger

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def handle_event(event_name, measurements, metadata, _) do
    GenStage.cast(
      __MODULE__,
      {:broadcast,
       %{
         event_name: event_name,
         measurements: measurements,
         metadata: metadata,
         t: DateTime.utc_now()
       }}
    )
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)
    metrics = Keyword.fetch!(opts, :metrics)

    state =
      metrics
      |> Enum.group_by(fn %{event_name: x} -> x end)
      |> Enum.map(fn {event, _metrics} ->
        id = {__MODULE__, event, self()}
        Logger.info("#{__MODULE__} attaching to #{inspect(event)}")
        :telemetry.attach(id, event, &__MODULE__.handle_event/4, %{})
        %{event: event}
      end)

    {:producer, state, dispatcher: GenStage.BroadcastDispatcher}
  end

  @impl true
  def terminate(reason, state) do
    Logger.warn("Broadcaster is terminating with reason: #{inspect(reason)}")

    state
    |> Enum.each(fn %{event: event} ->
      :telemetry.detach({__MODULE__, event, self()})
    end)

    state
  end

  @impl true
  def handle_cast({:broadcast, event}, state) do
    {:noreply, [event], state}
  end

  @impl true
  def handle_demand(_demand, state) do
    # we might collect items as soon as we have the requested demand.
    {:noreply, [], state}
  end
end
