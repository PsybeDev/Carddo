defmodule Carddo.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :stripe_customer_id, :string
    field :subscription_tier, :string, default: "free"

    has_many :games, Carddo.Game, foreign_key: :owner_id
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :stripe_customer_id, :subscription_tier])
    |> validate_required([:email])
    |> validate_format(:email, ~r/@/)
    |> validate_inclusion(:subscription_tier, ["free", "pro", "enterprise"])
    |> unique_constraint(:email)
  end
end
