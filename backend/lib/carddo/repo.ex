defmodule Carddo.Repo do
  use Ecto.Repo,
    otp_app: :carddo,
    adapter: Ecto.Adapters.Postgres
end
