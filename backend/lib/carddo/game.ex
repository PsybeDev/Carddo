defmodule Carddo.Game do
  use Ecto.Schema
  import Ecto.Changeset

  schema "games" do
    field(:title, :string)
    field(:description, :string)
    field(:config, :map, default: %{})

    field(:card_count, :integer, virtual: true, default: 0)

    belongs_to(:owner, Carddo.User)
    has_many(:decks, Carddo.Deck)
    has_many(:cards, Carddo.Card)
    timestamps()
  end

  def changeset(game, attrs) do
    game
    |> cast(attrs, [:title, :description])
    |> validate_required([:title, :owner_id])
    |> assoc_constraint(:owner)
  end

  def update_changeset(game, attrs) do
    game
    |> cast(attrs, [:title, :description, :config])
    |> validate_required([:title])
    |> assoc_constraint(:owner)
  end
end
