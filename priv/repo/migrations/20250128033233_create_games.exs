defmodule Carddo.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :name, :string
      add :description, :string
      add :state_machine, :map

      timestamps(type: :utc_datetime)
    end
  end
end
