defmodule Carddo.Deck do
  use Ecto.Schema
  import Ecto.Changeset

  schema "decks" do
    field :name, :string

    belongs_to :game, Carddo.Game
    has_many :deck_cards, Carddo.DeckCard
    many_to_many :cards, Carddo.Card, join_through: Carddo.DeckCard
    timestamps()
  end

  def changeset(deck, attrs) do
    deck
    |> cast(attrs, [:name])
    |> validate_required([:name, :game_id])
    |> foreign_key_constraint(:game_id)
  end
end
