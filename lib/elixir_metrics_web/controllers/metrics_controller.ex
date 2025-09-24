defmodule ElixirMetricsWeb.MetricsController do
  use ElixirMetricsWeb, :controller

  alias ElixirMetrics.Telemetry.Collector, as: TelemetryCollector
  alias ElixirMetrics.OpenTelemetry.Collector, as: OtelCollector
  alias ElixirMetrics.Metrics, as: Dog

  @doc """
  Test endpoint that emits metrics using Telemetry and/or OpenTelemetry,
  and always sends DogStatsD counters/timings.
  """
  def test(conn, %{"type" => type}) do
    start_time = System.monotonic_time(:millisecond)
    :timer.sleep(Enum.random(10..100))
    duration = System.monotonic_time(:millisecond) - start_time
    status = 200

    tags = [
      "env:dev",
      "service:elixir-metrics",
      "method:#{conn.method}",
      "path:#{conn.request_path}",
      "status:#{status}",
      "type:#{type}"
    ]

    case type do
      "telemetry" ->
        TelemetryCollector.track_http_request(conn.method, conn.request_path, status, duration)
        TelemetryCollector.track_custom_metric(:test_metric, Enum.random(1..100), %{type: "telemetry_test"})

      "opentelemetry" ->
        OtelCollector.track_http_request(conn.method, conn.request_path, status, duration)
        OtelCollector.track_custom_metric("test_metric", Enum.random(1..100), %{type: "otel_test"})

      "both" ->
        TelemetryCollector.track_http_request(conn.method, conn.request_path, status, duration)
        OtelCollector.track_http_request(conn.method, conn.request_path, status, duration)
        TelemetryCollector.track_custom_metric(:test_metric, Enum.random(1..100), %{type: "both"})
        OtelCollector.track_custom_metric("test_metric", Enum.random(1..100), %{type: "both"})

      _ ->
        :ok
    end

    # Always send DogStatsD too (prefix "custom." via Statix)
    Dog.incr("requests.total", 1, tags)
    Dog.timing_ms("request_latency_ms", duration, tags)

    json(conn, %{status: "ok", type: type, duration_ms: duration, timestamp: DateTime.utc_now()})
  end

  @doc """
  Simulate DB operation with metrics
  """
  def database(conn, %{"type" => type}) do
    start_time = System.monotonic_time(:millisecond)
    :timer.sleep(Enum.random(20..200))
    duration = System.monotonic_time(:millisecond) - start_time

    case type do
      "telemetry" -> TelemetryCollector.track_db_query("SELECT", "users", duration)
      "opentelemetry" -> OtelCollector.track_db_query("SELECT", "users", duration)
      "both" ->
        TelemetryCollector.track_db_query("SELECT", "users", duration)
        OtelCollector.track_db_query("SELECT", "users", duration)
      _ -> :ok
    end

    Dog.timing_ms("db.query", duration, [
      "env:dev",
      "service:elixir-metrics",
      "operation:select",
      "table:users",
      "type:#{type}"
    ])

    json(conn, %{status: "ok", operation: "database_query", duration_ms: duration})
  end

  @doc """
  Simulate background job with metrics
  """
  def job(conn, %{"type" => type}) do
    start_time = System.monotonic_time(:millisecond)
    :timer.sleep(Enum.random(50..500))
    duration = System.monotonic_time(:millisecond) - start_time
    success = Enum.random([true, true, true, false]) # 75% success

    case type do
      "telemetry" -> TelemetryCollector.track_job_execution("TestWorker", "default", duration, success)
      "opentelemetry" -> OtelCollector.track_job_execution("TestWorker", "default", duration, success)
      "both" ->
        TelemetryCollector.track_job_execution("TestWorker", "default", duration, success)
        OtelCollector.track_job_execution("TestWorker", "default", duration, success)
      _ -> :ok
    end

    Dog.incr("jobs.processed", 1, [
      "env:dev",
      "service:elixir-metrics",
      "worker:TestWorker",
      "queue:default",
      "success:#{success}",
      "type:#{type}"
    ])

    Dog.timing_ms("jobs.duration_ms", duration, [
      "env:dev",
      "service:elixir-metrics",
      "worker:TestWorker",
      "queue:default",
      "success:#{success}",
      "type:#{type}"
    ])

    json(conn, %{status: if(success, do: "success", else: "failed"), job: "TestWorker", duration_ms: duration})
  end

  @doc """
  Health check endpoint
  """
  def health(conn, _params) do
    json(conn, %{
      status: "healthy",
      timestamp: DateTime.utc_now(),
      metrics_backends: ["telemetry", "opentelemetry", "dogstatsd"]
    })
  end

  @doc """
  Get current metrics summary (stub)
  """
  def summary(conn, _params) do
    json(conn, %{
      telemetry_events: "Active",
      opentelemetry: "Active",
      dogstatsd: "Connected",
      total_events_processed: Enum.random(1000..10000)
    })
  end
end