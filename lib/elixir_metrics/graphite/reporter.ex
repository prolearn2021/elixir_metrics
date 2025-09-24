defmodule ElixirMetrics.Graphite.Reporter do
  @moduledoc """
  Graphite reporter using UDP client for sending metrics to StatsD/Graphite
  """
  use GenServer
  require Logger
  alias ElixirMetrics.Graphite.UDPClient

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Attach to telemetry events
    attach_handlers()

    Logger.info("Graphite reporter started with UDP client")
    {:ok, %{}}
  end

  def send_metric(name, value, tags \\ []) do
    GenServer.cast(__MODULE__, {:send_metric, name, value, tags})
  end

  def handle_cast({:send_metric, name, value, tags}, state) do
    metric_name = build_metric_name(name, tags)
    UDPClient.send_gauge(metric_name, value)
    Logger.info("Successfully sent to Graphite via UDP: #{metric_name} = #{value}")
    {:noreply, state}
  end

  defp attach_handlers do
    :telemetry.attach_many(
      "graphite-reporter",
      [
        [:elixir_metrics, :http, :request],
        [:elixir_metrics, :db, :query],
        [:elixir_metrics, :job, :execution]
      ],
      &handle_telemetry_event/4,
      nil
    )
  end

  defp handle_telemetry_event(event, measurements, metadata, _config) do
    Logger.debug("GraphiteReporter received telemetry event: #{inspect(event)} with measurements: #{inspect(measurements)}")
    event_name = Enum.join(event, ".")

    Enum.each(measurements, fn {key, value} ->
      metric_name = build_metric_name("#{event_name}.#{key}", metadata)
      UDPClient.send_gauge(metric_name, value)
      Logger.info("Successfully sent telemetry to Graphite via UDP: #{metric_name} = #{value}")
    end)
  end

  defp build_metric_name(name, tags) when is_map(tags) do
    build_metric_name(name, Map.to_list(tags))
  end

  defp build_metric_name(name, tags) when is_list(tags) do
    tag_string = tags
      |> Enum.map(fn {k, v} -> "#{k}_#{v}" end)
      |> Enum.join(".")

    if tag_string == "" do
      name
    else
      "#{name}.#{tag_string}"
    end
  end
end