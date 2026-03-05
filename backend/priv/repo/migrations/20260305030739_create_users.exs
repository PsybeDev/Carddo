defmodule Carddo.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :stripe_customer_id, :string
      add :subscription_tier, :string, null: false, default: "free"
      timestamps()
    end

    create unique_index(:users, [:email])
  end
end
