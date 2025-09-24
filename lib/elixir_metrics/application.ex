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

    # Boot-time ping (connects in this supervisor process only; request processes
    # will connect on-demand in controllers/jobs).
    host = System.get_env("STATSD_HOST", "datadog")
    port = System.get_env("STATSD_PORT", "8125") |> String.to_integer()

    case ElixirMetrics.Metrics.connect(host: host, port: port) do
      :ok ->
        Logger.info("✅ Statix connected to #{host}:#{port} for boot ping")
        ElixirMetrics.Metrics.incr("boot.ping", 1, ["env:dev", "service:elixir-metrics"])

      {:error, reason} ->
        Logger.warning("⚠️  Statix boot connect failed: #{inspect(reason)}")
    end

    {:ok, sup}
  end

  @impl true
  def config_change(changed, _new, removed) do
    ElixirMetricsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
