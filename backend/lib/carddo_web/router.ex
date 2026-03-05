defmodule CarddoWeb.Router do
  use CarddoWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated do
    plug :accepts, ["json"]
    plug CarddoWeb.Plugs.RequireAuth
  end

  scope "/api", CarddoWeb.Api, as: :api do
    pipe_through :api

    post "/users/register", UserController, :register
    post "/users/login", UserController, :login
  end

  scope "/api", CarddoWeb.Api, as: :api do
    pipe_through :authenticated

    get "/users/me", UserController, :me
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:carddo, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: CarddoWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
