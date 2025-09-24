defmodule ElixirMetrics.Metrics do
  @moduledoc """
  Thin wrapper around Statix (DogStatsD) with the `custom` prefix.
  """

  # Keep Statix simple here; the socket is opened by a dedicated GenServer
  # (ElixirMetrics.MetricsConnector) so it lives for the duration of the app.
  use Statix, runtime_config: true, prefix: "custom"

  # tiny helpers
  def incr(name, value \\ 1, tags \\ []), do: increment(name, value, tags: tags)
  def gauge(name, value, tags \\ []),     do: gauge(name, value, tags: tags)
  def timing_ms(name, ms, tags \\ []),    do: timing(name, ms, tags: tags)
end
