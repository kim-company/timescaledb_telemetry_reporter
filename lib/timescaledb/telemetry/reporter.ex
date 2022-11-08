defmodule TimescaleDB.Telemetry.Reporter do
  use GenServer
  require Logger
  
  alias TimescaleDB.Telemetry.Reporter.Metric

  def start_link(opts) do
    server_opts = Keyword.take(opts, [:name])

    metrics =
      opts[:metrics] ||
        raise ArgumentError, "the :metrics option is required by #{inspect(__MODULE__)}"
    repo =
      opts[:repo] ||
        raise ArgumentError, "the :repo option is required by #{inspect(__MODULE__)}"


    GenServer.start_link(__MODULE__, %{metrics: metrics, repo: repo}, server_opts)
  end

  @impl true
  def init(%{metrics: metrics, repo: repo}) do
    Process.flag(:trap_exit, true)
    groups = Enum.group_by(metrics, & &1.event_name)

    for {event, metrics} <- groups do
      id = {__MODULE__, event, self()}
      :telemetry.attach(id, event, &handle_event/4, %{metrics: metrics, repo: repo})
    end

    {:ok, Map.keys(groups)}
  end

  @impl true
  def terminate(_, events) do
    for event <- events do
      :telemetry.detach({__MODULE__, event, self()})
    end

    :ok
  end

  defp handle_event(event_name, measurements, metadata, %{metrics: metrics, repo: repo}) do
    event_name =  Enum.join(event_name, ".")

    for %struct{} = metric <- metrics do
      measurement = extract_measurement(metric, measurements, metadata)

      cond do
        is_nil(measurement) ->
          Logger.warn("Measurement #{event_name}: value is missing (metric skipped)")

        not keep?(metric, metadata) ->
          Logger.debug("Measurement #{event_name}: event dropped")

        true ->
          %Metric{
            time: DateTime.utc_now(),
            event_name: event_name,
            measurement: measurement,
            unit: unit(metric.unit),
            metric: metric(struct),
            tags: extract_tags(metric, metadata)
          }
          # TODO: aggregate metrics and write them in batches.
          |> repo.insert!()
      end
    end
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
