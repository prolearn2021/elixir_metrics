defmodule ElixirMetrics.Application do
  @moduledoc false
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      ElixirMetricsWeb.Telemetry,
      ElixirMetrics.Repo,
      {DNSCluster, query: Application.get_env(:elixir_metrics, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ElixirMetrics.PubSub},
      {Oban, Application.fetch_env!(:elixir_metrics, Oban)},
      ElixirMetricsWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ElixirMetrics.Supervisor]
    {:ok, sup} = Supervisor.start_link(children, opts)

    # ---- DogStatsD (Statix) connect w/ retry & periodic re-connect ----
    host_env = System.get_env("STATSD_HOST", "datadog")
    port =
      case System.get_env("STATSD_PORT", "8125") do
        p when is_integer(p) -> p
        p when is_binary(p)  -> String.to_integer(p)
      end

    host_ip =
      case :inet.getaddr(String.to_charlist(host_env), :inet) do
        {:ok, ip} ->
          ip
        {:error, reason} ->
          Logger.warning("Could not resolve #{host_env} (#{inspect(reason)}), using hostname")
          host_env
      end

    connect_ok? =
      1..10
      |> Enum.reduce_while(false, fn attempt, _acc ->
        case ElixirMetrics.Metrics.connect(host: host_ip, port: port) do
          :ok ->
            Logger.info("✅ Statix connected to #{inspect(host_ip)}:#{port} on attempt #{attempt}")
            # one-time boot metric to verify DogStatsD intake
            ElixirMetrics.Metrics.incr("boot.ping", 1, ["env:dev", "service:elixir-metrics"])
            {:halt, true}

          {:error, reason} ->
            Logger.warning("⚠️  Statix connect failed (#{inspect(reason)}) to #{inspect(host_ip)}:#{port}, retrying...")
            Process.sleep(300)
            {:cont, false}
        end
      end)

    unless connect_ok? do
      Logger.error("❌ Statix could not connect to #{inspect(host_ip)}:#{port}. DogStatsD metrics may be dropped.")
    end

    # Periodic, idempotent reconnect (handles UDP socket closure)
    _ = Task.Supervisor.start_child(Task.Supervisor, fn ->
      :timer.sleep(2_000)
      :ok = periodic_reconnect(host_ip, port)
    end) rescue :ok
    # -------------------------------------------------------------------

    {:ok, sup}
  end

  defp periodic_reconnect(host_ip, port) do
    case ElixirMetrics.Metrics.connect(host: host_ip, port: port) do
      :ok -> :ok
      {:error, reason} ->
        Logger.debug("Statix periodic reconnect failed: #{inspect(reason)}")
        :ok
    end

    :timer.sleep(5_000)
    periodic_reconnect(host_ip, port)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ElixirMetricsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end