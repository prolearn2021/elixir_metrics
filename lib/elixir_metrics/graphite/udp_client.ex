defmodule ElixirMetrics.Graphite.UDPClient do
  @moduledoc """
  Simple UDP client for sending metrics to StatsD/Graphite
  Bypasses Statix issues by using raw UDP sockets
  """
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    config = Application.get_env(:elixir_metrics, ElixirMetrics.Graphite.UDPClient, [])
    host = Keyword.get(config, :host, "localhost")
    port = Keyword.get(config, :port, 8125)
    prefix = Keyword.get(config, :prefix, "elixir_metrics")

    # Convert hostname to IP tuple
    host_tuple = case :inet.getaddr(String.to_charlist(host), :inet) do
      {:ok, ip} -> ip
      {:error, _} -> {127, 0, 0, 1}  # fallback to localhost
    end

    {:ok, socket} = :gen_udp.open(0)

    state = %{
      socket: socket,
      host: host_tuple,
      port: port,
      prefix: prefix
    }

    Logger.info("UDP metrics client started - #{inspect(host_tuple)}:#{port}")
    {:ok, state}
  end

  def send_gauge(name, value) do
    GenServer.cast(__MODULE__, {:send_metric, name, value, "g"})
  end

  def send_counter(name, value \\ 1) do
    GenServer.cast(__MODULE__, {:send_metric, name, value, "c"})
  end

  def send_timer(name, value) do
    GenServer.cast(__MODULE__, {:send_metric, name, value, "ms"})
  end

  def handle_cast({:send_metric, name, value, type}, state) do
    metric_name = "#{state.prefix}.#{name}"
    message = "#{metric_name}:#{value}|#{type}"

    case :gen_udp.send(state.socket, state.host, state.port, message) do
      :ok ->
        Logger.debug("Sent metric: #{message}")
      {:error, reason} ->
        Logger.error("Failed to send metric #{message}: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  def terminate(_reason, state) do
    :gen_udp.close(state.socket)
    :ok
  end
end