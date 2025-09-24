defmodule ElixirMetrics.MetricsConn do
  @moduledoc """
  Long-lived process that owns the UDP socket used by Statix (DogStatsD).

  We connect in `init/1` and keep retrying until it succeeds so metrics
  aren't dropped on boot if the Agent isn't ready yet.
  """
  use GenServer
  require Logger

  @retry_initial_ms 300
  @retry_max_ms 2_000

  # Public API ---------------------------------------------------------------

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  # GenServer callbacks ------------------------------------------------------

  @impl true
  def init(opts) do
    host = Keyword.get(opts, :host, System.get_env("STATSD_HOST", "datadog"))
    port = port_to_int(Keyword.get(opts, :port, System.get_env("STATSD_PORT", "8125")))
    state = %{host: host, port: port, backoff: @retry_initial_ms}

    case ElixirMetrics.Metrics.connect(host: host, port: port) do
      :ok ->
        Logger.info("✅ Statix connected to #{host}:#{port}")
        # Optional boot ping so you can grep it from the Agent
        ElixirMetrics.Metrics.incr("boot.ping", 1, ["env:dev", "service:elixir-metrics"])
        {:ok, state}

      {:error, reason} ->
        Logger.warning("⚠️ Statix connect failed to #{host}:#{port} (#{inspect(reason)}), retrying...")
        Process.send_after(self(), :retry_connect, state.backoff)
        {:ok, state}
    end
  end

  @impl true
  def handle_info(:retry_connect, %{host: host, port: port, backoff: backoff} = state) do
    case ElixirMetrics.Metrics.connect(host: host, port: port) do
      :ok ->
        Logger.info("✅ Statix connected to #{host}:#{port} (after retry)")
        ElixirMetrics.Metrics.incr("boot.ping", 1, ["env:dev", "service:elixir-metrics"])
        {:noreply, %{state | backoff: @retry_initial_ms}}

      {:error, reason} ->
        next = min(backoff * 2, @retry_max_ms)
        Logger.warning("⚠️ Statix retry failed (#{inspect(reason)}), next in #{next} ms")
        Process.send_after(self(), :retry_connect, next)
        {:noreply, %{state | backoff: next}}
    end
  end

  # Helpers -----------------------------------------------------------------

  defp port_to_int(p) when is_integer(p), do: p
  defp port_to_int(p) when is_binary(p) do
    case Integer.parse(p) do
      {i, ""} -> i
      _ -> 8125
    end
  end
end