defmodule ElixirMetrics.MetricsConnector do
  @moduledoc """
  Supervised, long-lived process that *owns* the DogStatsD UDP socket.

  We do the `ElixirMetrics.Metrics.connect/1` here so the port belongs to this
  GenServer (which is kept alive by the supervision tree), preventing the
  “lost value due to port closure” errors you were seeing.
  """

  use GenServer
  require Logger

  # -- Public API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # -- GenServer callbacks

  @impl true
  def init(opts) do
    host = Keyword.get(opts, :host, System.get_env("STATSD_HOST", "datadog"))
    port =
      case Keyword.get(opts, :port, System.get_env("STATSD_PORT", "8125")) do
        p when is_integer(p) -> p
        p when is_binary(p)  -> String.to_integer(p)
      end

    # Try a few times at boot in case the Agent isn't ready yet.
    connect_with_retry(host, port, attempts: 10, backoff_ms: 300)

    # Send a single boot ping so you can confirm delivery in the Agent.
    ElixirMetrics.Metrics.incr("boot.ping", 1, ["env:dev", "service:elixir-metrics"])

    {:ok, %{host: host, port: port}}
  end

  # -- Helpers

  defp connect_with_retry(host, port, attempts: attempts, backoff_ms: backoff) do
    1..attempts
    |> Enum.reduce_while(nil, fn attempt, _ ->
      case ElixirMetrics.Metrics.connect(host: host, port: port) do
        :ok ->
          Logger.info("✅ Statix connected to #{host}:#{port} on attempt #{attempt}")
          {:halt, :ok}

        {:error, reason} ->
          Logger.warning(
            "⚠️  Statix connect failed (#{inspect(reason)}) to #{host}:#{port}, retrying..."
          )

          Process.sleep(backoff)
          {:cont, nil}
      end
    end)
    |> case do
      :ok -> :ok
      _ ->
        Logger.error("❌ Statix could not connect to #{host}:#{port}. Metrics will be dropped.")
        :ok
    end
  end
end
