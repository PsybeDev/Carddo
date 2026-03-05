defmodule Carddo.DeckCard do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "deck_cards" do
    belongs_to :deck, Carddo.Deck
    belongs_to :card, Carddo.Card
    field :quantity, :integer, default: 1
  end

  def changeset(deck_card, attrs) do
    deck_card
    |> cast(attrs, [:deck_id, :card_id, :quantity])
    |> validate_required([:deck_id, :card_id, :quantity])
    |> validate_number(:quantity, greater_than_or_equal_to: 1)
    |> unique_constraint([:deck_id, :card_id], name: :deck_cards_pkey)
  end
end
