defmodule ElixirMetricsWeb.Router do
  use ElixirMetricsWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", ElixirMetricsWeb do
    pipe_through :api

    # Health & Info
    get "/health", MetricsController, :health
    get "/metrics/summary", MetricsController, :summary

    # Test endpoints for metrics comparison
    post "/metrics/test/:type", MetricsController, :test
    post "/metrics/database/:type", MetricsController, :database
    post "/metrics/job/:type", MetricsController, :job

  end

  # Enable LiveDashboard in development
  if Application.compile_env(:elixir_metrics, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: ElixirMetricsWeb.Telemetry
    end
  end
end
