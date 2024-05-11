defmodule Carddo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CarddoWeb.Telemetry,
      Carddo.Repo,
      {DNSCluster, query: Application.get_env(:carddo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Carddo.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Carddo.Finch},
      # Start a worker by calling: Carddo.Worker.start_link(arg)
      # {Carddo.Worker, arg},
      # Start to serve requests, typically the last entry
      CarddoWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Carddo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CarddoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
