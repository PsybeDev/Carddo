defmodule Carddo.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :stripe_customer_id, :string
    field :subscription_tier, :string, default: "free"
    field :password_hash, :string
    field :password, :string, virtual: true

    has_many :games, Carddo.Game, foreign_key: :owner_id
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :stripe_customer_id])
    |> validate_required([:email])
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:email)
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/@/)
    |> validate_length(:password, min: 8)
    |> unique_constraint(:email)
    |> hash_password()
  end

  defp hash_password(%Ecto.Changeset{valid?: true, changes: %{password: pw}} = changeset) do
    put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(pw))
  end

  defp hash_password(changeset), do: changeset
end
