defmodule Carddo.Repo.Migrations.CreateDeckCards do
  use Ecto.Migration

  def change do
    create table(:deck_cards, primary_key: false) do
      add :deck_id, references(:decks, on_delete: :delete_all), null: false
      add :card_id, references(:cards, on_delete: :delete_all), null: false
      add :quantity, :integer, default: 1, null: false
    end

    execute(
      "ALTER TABLE deck_cards ADD PRIMARY KEY (deck_id, card_id)",
      "ALTER TABLE deck_cards DROP CONSTRAINT deck_cards_pkey"
    )

    execute(
      "ALTER TABLE deck_cards ADD CONSTRAINT quantity_positive CHECK (quantity >= 1)",
      "ALTER TABLE deck_cards DROP CONSTRAINT quantity_positive"
    )

    create index(:deck_cards, [:card_id])
  end
end
