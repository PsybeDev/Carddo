defmodule Carddo.Card do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cards" do
    field :name, :string
    field :card_type, :string
    field :properties, :map, default: %{}
    field :abilities, {:array, :map}, default: []

    belongs_to :game, Carddo.Game
    has_many :deck_cards, Carddo.DeckCard
    timestamps()
  end

  def changeset(card, attrs) do
    card
    |> cast(attrs, [:name, :card_type, :properties, :abilities])
    |> validate_required([:name, :card_type])
    |> assoc_constraint(:game)
  end
end
