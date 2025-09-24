defmodule ElixirMetrics.Metrics do
  @moduledoc """
  DogStatsD (Datadog) metrics via Statix.

  NOTE: Statix keeps the UDP socket **per-process**. Call `ensure_connected/0`
  in any process that emits metrics (HTTP requests, Oban jobs, etc).
  """

  use Statix, runtime_config: true, prefix: "custom"
  require Logger

  @doc """
  Ensure the **current process** has a Statix UDP socket.

  Safe to call multiple times; it connects only once per process.
  """
  def ensure_connected(opts \\ []) do
    case Process.get(:dogstatsd_connected?) do
      true -> :ok
      _ ->
        host = System.get_env("STATSD_HOST", "datadog")
        port = System.get_env("STATSD_PORT", "8125") |> to_int()

        case connect(Keyword.merge([host: host, port: port], opts)) do
          :ok ->
            Process.put(:dogstatsd_connected?, true)
            :ok

          {:error, reason} ->
            # Don’t spam logs; use debug so we can turn it on if needed.
            Logger.debug("Statix connect failed in #{inspect(self())}: #{inspect(reason)}")
            :ok
        end
    end
  end

  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_binary(v), do: String.to_integer(v)

  # tiny helpers (prefix "custom." via `use Statix` above)
  def incr(name, value \\ 1, tags \\ []),  do: increment(name, value, tags: tags)
  def gauge(name, value, tags \\ []),      do: gauge(name, value, tags: tags)
  def timing_ms(name, ms, tags \\ []),     do: timing(name, ms, tags: tags)
end
