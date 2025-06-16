defmodule Carddo.Games.Card do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cards" do
    field :name, :string
    field :cost, :integer
    field :power, :integer
    field :toughness, :integer
    field :description, :string
    field :type, :string
    field :abilities, {:array, :string}
    field :image_url, :string
    belongs_to :game, Carddo.Games.Game

    timestamps(type: :utc_datetime)
  end

  def changeset(card, attrs) do
    card
    |> cast(attrs, [:name, :cost, :power, :toughness, :description, :type, :abilities, :image_url])
    |> validate_required([:name, :cost, :power, :toughness])
    |> validate_length(:name, min: 1)
    |> validate_length(:description, max: 500)
    |> validate_inclusion(:type, ["creature", "spell", "artifact", "enchantment", "planeswalker"])
  end

end
