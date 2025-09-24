defmodule ElixirMetrics.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ElixirMetricsWeb.Telemetry,
      ElixirMetrics.Repo,
      {DNSCluster, query: Application.get_env(:elixir_metrics, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ElixirMetrics.PubSub},
      {Oban, Application.fetch_env!(:elixir_metrics, Oban)},

      # 👇 Own the DogStatsD socket in a supervised, long-lived process
      {ElixirMetrics.MetricsConnector, []},

      # Start the HTTP endpoint last
      ElixirMetricsWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ElixirMetrics.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ElixirMetricsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
