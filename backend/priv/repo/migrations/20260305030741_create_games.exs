defmodule Carddo.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :owner_id, references(:users, on_delete: :delete_all), null: false
      add :title, :string, null: false
      timestamps()
    end

    create index(:games, [:owner_id])
  end
end
