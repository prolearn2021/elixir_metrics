defmodule ElixirMetrics.Metrics do
  @moduledoc """
  Thin Statix wrapper with a fixed prefix `custom`.

  Use:
    ElixirMetrics.Metrics.incr("requests.total", 1, ["env:dev"])
    ElixirMetrics.Metrics.timing_ms("request_latency_ms", 42, ["env:dev"])
  """

  # allow runtime host/port changes (so we can connect to the Agent at boot)
  use Statix, runtime_config: true, prefix: "custom"

  # tiny helpers
  def incr(name, value \\ 1, tags \\ []), do: increment(name, value, tags: tags)
  def gauge(name, value, tags \\ []),     do: gauge(name, value, tags: tags)
  def timing_ms(name, ms, tags \\ []),    do: timing(name, ms, tags: tags)
end