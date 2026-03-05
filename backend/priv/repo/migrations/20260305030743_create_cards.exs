defmodule Carddo.Repo.Migrations.CreateCards do
  use Ecto.Migration

  def change do
    create table(:cards) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :card_type, :string, null: false
      add :properties, :map, null: false, default: %{}
      add :abilities, {:array, :map}, null: false, default: []
      timestamps()
    end

    create index(:cards, [:game_id])
    create index(:cards, [:properties], using: :gin, name: :cards_properties_gin)
    create index(:cards, [:abilities], using: :gin, name: :cards_abilities_gin)
  end
end
