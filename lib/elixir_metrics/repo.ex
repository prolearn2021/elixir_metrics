defmodule ElixirMetrics.Repo do
  use Ecto.Repo,
    otp_app: :elixir_metrics,
    adapter: Ecto.Adapters.Postgres
end
