defmodule ElixirMetricsWeb.MetricsController do
  use ElixirMetricsWeb, :controller

  alias ElixirMetrics.Telemetry.Collector, as: TelemetryCollector
  alias ElixirMetrics.OpenTelemetry.Collector, as: OtelCollector
  alias ElixirMetrics.Metrics, as: Dog  # <— DogStatsD

  @doc """
  Test endpoint that emits metrics via Telemetry, OpenTelemetry, and DogStatsD.
  """
  def test(conn, %{"type" => type}) do
    start_ms = System.monotonic_time(:millisecond)
    :timer.sleep(Enum.random(10..100))
    duration = System.monotonic_time(:millisecond) - start_ms

    tags = [
      "service:elixir-metrics",
      "env:dev",
      "path:#{conn.request_path}",
      "method:#{conn.method |> String.downcase()}",
      "type:#{type}"
    ]

    case type do
      "telemetry" ->
        TelemetryCollector.track_http_request(conn.method, conn.request_path, 200, duration)
        TelemetryCollector.track_custom_metric(:test_metric, Enum.random(1..100), %{type: "telemetry_test"})
        # DogStatsD
        Dog.incr("requests.total", 1, tags)
        Dog.timing_ms("request_latency_ms", duration, tags)

      "opentelemetry" ->
        OtelCollector.track_http_request(conn.method, conn.request_path, 200, duration)
        OtelCollector.track_custom_metric("test_metric", Enum.random(1..100), %{type: "otel_test"})
        # DogStatsD
        Dog.incr("requests.total", 1, tags)
        Dog.timing_ms("request_latency_ms", duration, tags)

      "both" ->
        TelemetryCollector.track_http_request(conn.method, conn.request_path, 200, duration)
        OtelCollector.track_http_request(conn.method, conn.request_path, 200, duration)
        # DogStatsD
        Dog.incr("requests.total", 1, tags)
        Dog.timing_ms("request_latency_ms", duration, tags)
    end

    json(conn, %{status: "ok", type: type, duration_ms: duration, timestamp: DateTime.utc_now()})
  end
end