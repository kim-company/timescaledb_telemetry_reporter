defmodule TimescaleDB.Telemetry.Reporter.Sink do
  use GenServer
  require Logger

  alias TimescaleDB.Telemetry.Reporter.Metric

  @default_buffer_cap 300
  @default_buffer_flush_interval_ms 3 * 1000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def handle(pid, event_name, measurements, metadata) do
    GenServer.cast(pid, {:event, event_name, measurements, metadata})
  end

  def stop(pid, reason \\ :normal, timeout \\ :infinity) do
    GenServer.stop(pid, reason, timeout)
  end

  def flush(state = %{queue: queue, repo: repo, telemetry_label: label}) do
    metrics = Enum.into(queue.queue, [])
    repo.insert_all(Metric, metrics)
    %{state | queue: Q.new(label)}
  end

  def flush(pid) do
    GenServer.call(pid, :flush)
  end

  @impl true
  def init(opts) do
    # mandatory
    [metrics, repo] =
      Enum.map([:metrics, :repo], fn key ->
        Keyword.fetch!(opts, key)
      end)

    extra_tags =
      opts
      |> Keyword.take([:namespace])
      |> Enum.into(%{})

    cap = Keyword.get(opts, :buffer_cap, @default_buffer_cap)
    telemetry_label = Keyword.get(opts, :telemetry_label, "#{__MODULE__}")
    queue = Q.new(telemetry_label)
    
    :erlang.start_timer(@default_buffer_flush_interval_ms, self(), :flush)

    {:ok,
     %{
       queue: queue,
       cap: cap,
       metrics: metrics,
       repo: repo,
       extra_tags: extra_tags,
       telemetry_label: telemetry_label,
     }}
  end

  @impl true
  def handle_cast({:event, event_name, measurements, metadata}, state) do
    %{queue: queue, metrics: metrics, extra_tags: extra_tags, cap: cap} = state

    event_name = Enum.join(event_name, ".")
    now = DateTime.utc_now()

    queue =
      metrics
      |> Enum.map(fn %struct{} = metric ->
        measurement = extract_measurement(metric, measurements, metadata)

        cond do
          is_nil(measurement) ->
            Logger.warn("Measurement #{event_name}: value is missing in #{inspect measurements} (metric skipped)")
            nil

          not keep?(metric, metadata) ->
            nil

          true ->
            %{
              time: now,
              event_name: event_name,
              measurement: measurement,
              unit: unit(metric.unit),
              metric: metric(struct),
              tags: Map.merge(extra_tags, extract_tags(metric, metadata))
            }
        end
      end)
      |> Enum.filter(fn x -> x != nil end)
      |> Enum.reduce(queue, fn metric, queue ->
        Q.push(queue, metric)
      end)

    state = %{state | queue: queue}

    state =
      if queue.count >= cap do
        flush(state)
      else
        state
      end

    {:noreply, state}
  end
  
  @impl true
  def handle_call(:flush, _from, state) do
    {:reply, :ok, flush(state)}
  end
  
  @impl true
  def handle_info({:timeout, _, :flush}, state) do
    {:noreply, flush(state)}
  end

  defp keep?(%{keep: nil}, _metadata), do: true
  defp keep?(metric, metadata), do: metric.keep.(metadata)

  defp extract_measurement(metric, measurements, metadata) do
    case metric.measurement do
      fun when is_function(fun, 2) -> fun.(measurements, metadata)
      fun when is_function(fun, 1) -> fun.(measurements)
      key -> measurements[key]
    end
  end

  defp unit(:unit), do: ""
  defp unit(unit), do: "#{unit}"

  defp metric(Telemetry.Metrics.Counter), do: "counter"
  defp metric(Telemetry.Metrics.Distribution), do: "distribution"
  defp metric(Telemetry.Metrics.LastValue), do: "last_value"
  defp metric(Telemetry.Metrics.Sum), do: "sum"
  defp metric(Telemetry.Metrics.Summary), do: "summary"

  defp extract_tags(metric, metadata) do
    tag_values = metric.tag_values.(metadata)
    Map.take(tag_values, metric.tags)
  end
end
