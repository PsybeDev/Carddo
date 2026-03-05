defmodule Carddo.Game do
  use Ecto.Schema
  import Ecto.Changeset

  schema "games" do
    field :title, :string

    belongs_to :owner, Carddo.User
    has_many :decks, Carddo.Deck
    has_many :cards, Carddo.Card
    timestamps()
  end

  def changeset(game, attrs) do
    game
    |> cast(attrs, [:title])
    |> validate_required([:title])
    |> assoc_constraint(:owner)
  end
end
