defmodule ElixirMetrics.Metrics do
  @moduledoc """
  Thin wrapper around Statix with a `custom` prefix.

  Use:
    Dog.incr("requests.total", 1, tags)
    Dog.timing_ms("request_latency_ms", duration, tags)
  will appear as:
    custom.requests.total
    custom.request_latency_ms
  """
  use Statix, runtime_config: true, prefix: "custom"

  # convenience wrappers
  def incr(name, value \\ 1, tags \\ []), do: increment(name, value, tags: tags)
  def gauge(name, value, tags \\ []), do: gauge(name, value, tags: tags)
  def timing_ms(name, ms, tags \\ []), do: timing(name, ms, tags: tags)
end