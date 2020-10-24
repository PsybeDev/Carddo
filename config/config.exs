# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :carddo,
  ecto_repos: [Carddo.Repo]

# Configures the endpoint
config :carddo, CarddoWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "sLQHNgWNx/eccB1WNjZCwN0Rh9RWATYIjgd5ZLZPUeZAiyQEqn4iGrbYH3MOH/Qv",
  render_errors: [view: CarddoWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Carddo.PubSub,
  live_view: [signing_salt: "kfQnJceT"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Use Pow
config :carddo, :pow,
  user: Carddo.Users.User,
  repo: Carddo.Repo

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
