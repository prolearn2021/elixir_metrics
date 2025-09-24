defmodule ElixirMetrics.OpenTelemetry.Collector do
  @moduledoc """
  OpenTelemetry metrics collector for comparison
  """
  require OpenTelemetry.Tracer
  alias OpenTelemetry.Tracer
  require Logger

  @doc """
  Track HTTP request with OpenTelemetry
  """
  def track_http_request(method, path, status, duration_ms) do
    Tracer.with_span "http.request" do
      Tracer.set_attributes([
        {"http.method", to_string(method)},
        {"http.path", path},
        {"http.status_code", status},
        {"http.duration_ms", duration_ms}
      ])

      Logger.debug("OpenTelemetry span created for HTTP request")
    end
  end

  @doc """
  Track database query with OpenTelemetry
  """
  def track_db_query(query_type, table, duration_ms) do
    Tracer.with_span "db.query" do
      Tracer.set_attributes([
        {"db.operation", to_string(query_type)},
        {"db.table", table},
        {"db.duration_ms", duration_ms}
      ])
    end
  end

  @doc """
  Track background job with OpenTelemetry
  """
  def track_job_execution(worker, queue, duration_ms, success) do
    Tracer.with_span "job.execution" do
      Tracer.set_attributes([
        {"job.worker", worker},
        {"job.queue", to_string(queue)},
        {"job.duration_ms", duration_ms},
        {"job.success", success}
      ])
    end
  end

  @doc """
  Track custom metric with OpenTelemetry
  """
  def track_custom_metric(name, value, metadata \\ %{}) do
    Tracer.with_span "custom.#{name}" do
      attributes = [{"metric.value", value}] ++
        Enum.map(metadata, fn {k, v} -> {to_string(k), to_string(v)} end)

      Tracer.set_attributes(attributes)
    end
  end

  @doc """
  Start a new trace span
  """
  def start_span(name) do
    Tracer.start_span(name)
    Tracer.set_current_span(name)
  end

  @doc """
  End the current span
  """
  def end_span do
    Tracer.end_span()
  end
end