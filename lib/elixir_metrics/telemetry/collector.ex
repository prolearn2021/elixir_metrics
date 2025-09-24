defmodule ElixirMetrics.Telemetry.Collector do
  @moduledoc """
  Native Elixir Telemetry metrics collector
  """
  require Logger

  @doc """
  Emit a custom metric using Telemetry.execute
  """
  def emit_metric(event_name, measurements, metadata \\ %{}) do
    start_time = System.monotonic_time()

    # Emit the telemetry event
    :telemetry.execute(
      [:elixir_metrics | List.wrap(event_name)],
      measurements,
      Map.put(metadata, :timestamp, DateTime.utc_now())
    )

    duration = System.monotonic_time() - start_time
    Logger.debug("Telemetry event emitted: #{inspect(event_name)} in #{duration} native units")
  end

  @doc """
  Emit HTTP request metrics
  """
  def track_http_request(method, path, status, duration_ms) do
    emit_metric(
      [:http, :request],
      %{
        duration: duration_ms,
        count: 1
      },
      %{
        method: method,
        path: path,
        status: status
      }
    )
  end

  @doc """
  Emit database query metrics
  """
  def track_db_query(query_type, table, duration_ms) do
    emit_metric(
      [:db, :query],
      %{
        duration: duration_ms,
        count: 1
      },
      %{
        query_type: query_type,
        table: table
      }
    )
  end

  @doc """
  Emit background job metrics
  """
  def track_job_execution(worker, queue, duration_ms, success) do
    emit_metric(
      [:job, :execution],
      %{
        duration: duration_ms,
        count: 1
      },
      %{
        worker: worker,
        queue: queue,
        success: success
      }
    )
  end

  @doc """
  Emit custom business metrics
  """
  def track_custom_metric(name, value, metadata \\ %{}) do
    emit_metric(
      [:custom, name],
      %{value: value},
      metadata
    )
  end
end