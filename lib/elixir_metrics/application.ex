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
    {:ok, sup_pid} = Supervisor.start_link(children, opts)

    # connect Statix (DogStatsD) after the tree is up
    connect_dogstatsd()

    {:ok, sup_pid}
  end

  defp connect_dogstatsd do
    host = System.get_env("STATSD_HOST", "datadog")

    port =
      case System.get_env("STATSD_PORT", "8125") do
        p when is_integer(p) -> p
        p when is_binary(p) -> String.to_integer(p)
      end

    max_attempts = 10

    result =
      Enum.reduce_while(1..max_attempts, :error, fn attempt, _acc ->
        case ElixirMetrics.Metrics.connect(host: host, port: port) do
          :ok ->
            Logger.info("✅ Statix connected to #{host}:#{port} on attempt #{attempt}")
            # optional boot ping to confirm path end-to-end
            ElixirMetrics.Metrics.incr("boot.ping", 1, ["env:dev", "service:elixir-metrics"])
            {:halt, :ok}

          {:error, reason} ->
            Logger.warning(
              "⚠️  Statix connect failed (#{inspect(reason)}) to #{host}:#{port}, retrying..."
            )

            Process.sleep(300)
            {:cont, :error}

          other ->
            Logger.warning("⚠️  Statix connect unexpected reply: #{inspect(other)}")
            Process.sleep(300)
            {:cont, :error}
        end
      end)

    case result do
      :ok -> :ok
      _ -> Logger.error("❌ Statix could not connect to #{host}:#{port}. DogStatsD metrics will be dropped.")
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    ElixirMetricsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
