# config/config.exs

import Config

# General application configuration
config :elixir_metrics,
  ecto_repos: [ElixirMetrics.Repo],
  generators: [timestamp_type: :utc_datetime]

# --- Endpoint (common) ---
config :elixir_metrics, ElixirMetricsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [json: ElixirMetricsWeb.ErrorJSON], layout: false],
  pubsub_server: ElixirMetrics.PubSub,
  live_view: [signing_salt: "fY7fPYYK"]

# Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# JSON
config :phoenix, :json_library, Jason

# --- Database ---
# Match docker-compose env vars; provide sensible defaults for local dev.
config :elixir_metrics, ElixirMetrics.Repo,
  username: System.get_env("DB_USERNAME", "postgres"),   # was DB_USER
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost"),
  database: System.get_env("DB_NAME", "elixir_metrics_dev"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Test DB
if Mix.env() == :test do
  config :elixir_metrics, ElixirMetrics.Repo,
    username: System.get_env("DB_USERNAME", "postgres"),
    password: System.get_env("DB_PASSWORD", "postgres"),
    hostname: System.get_env("DB_HOST", "localhost"),
    database: System.get_env("DB_NAME", "elixir_metrics_test"),
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10
end

# --- Oban ---
config :elixir_metrics, Oban,
  repo: ElixirMetrics.Repo,
  queues: [default: 10, metrics: 20, events: 15]

# --- StatsD / DogStatsD (send to Datadog Agent) ---
# Accept STATSD_* or fall back to GRAPHITE_* for backward-compat.
config :elixir_metrics, ElixirMetrics.Graphite.UDPClient,
  host:
    System.get_env("STATSD_HOST") ||
      System.get_env("GRAPHITE_HOST") ||
      "datadog",
  port:
    String.to_integer(
      System.get_env("STATSD_PORT") ||
        System.get_env("GRAPHITE_PORT") ||
        "8125"
    ),
  prefix: System.get_env("STATSD_PREFIX") || "elixir_metrics"

# --- OpenTelemetry (enable exporter; Agent will ingest OTLP) ---
# Keep it simple: use HTTP/protobuf to the endpoint in env (defaults to Agent)
config :opentelemetry, :processors,
  otel_batch_processor: %{
    exporter:
      {:opentelemetry_exporter,
       otlp_protocol: :http_protobuf,
       otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://datadog:4318")}
  }

# --- Development-only settings ---
config :elixir_metrics, ElixirMetricsWeb.Endpoint,
  # IMPORTANT: listen on all interfaces in Docker
  http: [ip: {0, 0, 0, 0}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  server: true,
  secret_key_base: "nv23cGOkjflEsSHMf68sIvL0f6pwFLkDSZ7TqIzjqzbJBq2qiD3MUdt1vQWeh2Go"

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

# Cleaner dev console format
config :logger, :default_formatter, format: "[$level] $message\n"