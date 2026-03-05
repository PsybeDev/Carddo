defmodule Carddo.Repo.Migrations.CreateCards do
  use Ecto.Migration

  def up do
    create table(:cards) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :card_type, :string, null: false
      add :properties, :map, null: false, default: %{}
      add :abilities, {:array, :map}, null: false, default: []
      timestamps()
    end

    create index(:cards, [:game_id])
    execute "CREATE INDEX cards_properties_gin ON cards USING GIN (properties)"
    execute "CREATE INDEX cards_abilities_gin ON cards USING GIN (abilities)"
  end

  def down do
    execute "DROP INDEX IF EXISTS cards_abilities_gin"
    execute "DROP INDEX IF EXISTS cards_properties_gin"
    drop_if_exists index(:cards, [:game_id])
    drop_if_exists table(:cards)
  end
end
