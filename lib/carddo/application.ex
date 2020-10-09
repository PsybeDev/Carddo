defmodule Carddo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Carddo.Repo,
      # Start the Telemetry supervisor
      CarddoWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Carddo.PubSub},
      # Start the Endpoint (http/https)
      CarddoWeb.Endpoint
      # Start a worker by calling: Carddo.Worker.start_link(arg)
      # {Carddo.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Carddo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    CarddoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
