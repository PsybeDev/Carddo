defmodule Carddo.Deck do
  use Ecto.Schema
  import Ecto.Changeset

  schema "decks" do
    field :name, :string

    belongs_to :game, Carddo.Game
    timestamps()
  end

  def changeset(deck, attrs) do
    deck
    |> cast(attrs, [:name, :game_id])
    |> validate_required([:name, :game_id])
  end
end
