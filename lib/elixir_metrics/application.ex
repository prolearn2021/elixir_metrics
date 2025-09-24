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

    # ---- DogStatsD (Statix) connect with retry ----
    host = System.get_env("STATSD_HOST", "datadog")
    port =
      case System.get_env("STATSD_PORT", "8125") do
        p when is_integer(p) -> p
        p when is_binary(p)  -> String.to_integer(p)
      end

    connect_ok? =
      1..10
      |> Enum.reduce_while(false, fn attempt, _acc ->
        case ElixirMetrics.Metrics.connect(host: host, port: port) do
          :ok ->
            Logger.info("✅ Statix connected to #{host}:#{port} on attempt #{attempt}")
            # send a boot ping so we can see it in the Agent
            ElixirMetrics.Metrics.incr("boot.ping", 1, ["env:dev", "service:elixir-metrics"])
            {:halt, true}

          {:error, reason} ->
            Logger.warning("⚠️  Statix connect failed (#{inspect(reason)}) to #{host}:#{port}, retrying...")
            Process.sleep(300)
            {:cont, false}
        end
      end)

    unless connect_ok? do
      Logger.error("❌ Statix could not connect to #{host}:#{port}. DogStatsD metrics will be dropped.")
    end
    # ----------------------------------------------

    {:ok, sup}
  end

  @impl true
  def config_change(changed, _new, removed) do
    ElixirMetricsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end