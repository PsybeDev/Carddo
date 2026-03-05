defmodule Carddo.Repo.Migrations.CreateDecks do
  use Ecto.Migration

  def change do
    create table(:decks) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :name, :string, null: false
      timestamps()
    end

    create index(:decks, [:game_id])
  end
end
