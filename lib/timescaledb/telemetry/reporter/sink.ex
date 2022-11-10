defmodule TimescaleDB.Telemetry.Reporter.Sink do
  use GenStage

  alias TimescaleDB.Telemetry.Reporter.{Broadcaster, Metric}

  def start_link(opts) do
    metrics = Keyword.fetch!(opts, :metrics)
    repo = Keyword.fetch!(opts, :repo)
    extra_tags = Keyword.get(opts, :extra_tags, %{})
    GenStage.start_link(__MODULE__, %{metrics: metrics, extra_tags: extra_tags, repo: repo})
  end

  @impl true
  def init(config) do
    {:consumer, config, subscribe_to: [Broadcaster]}
  end

  @impl true
  def handle_events(events, _from, state) do
    metrics = Enum.flat_map(events, &to_reporter_metrics(&1, state))

    try do
      state.repo.insert_all(Metric, metrics)
    rescue
      DBConnection.ConnectionError ->
        :ok
    end

    {:noreply, [], state}
  end

  defp to_reporter_metrics(
         %{event_name: event_name, measurements: measurements, metadata: metadata, t: t},
         state
       ) do
    %{metrics: metrics, extra_tags: extra_tags} = state
    event_name = Enum.join(event_name, ".")

    metrics
    |> Enum.map(fn %struct{} = metric ->
      measurement = extract_measurement(metric, measurements, metadata)
      skip? = is_nil(measurement) or not keep?(metric, metadata)

      if skip? do
        # Logger.warn(
        #   "Measurement #{event_name}: #{inspect metric} is missing in #{inspect(measurements)} (metric skipped)"
        # )

        nil
      else
        %{
          time: t,
          event_name: event_name,
          measurement: measurement,
          unit: unit(metric.unit),
          metric: metric(struct),
          tags: Map.merge(extra_tags, extract_tags(metric, metadata))
        }
      end
    end)
    |> Enum.filter(fn x -> x != nil end)
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
