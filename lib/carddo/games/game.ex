defmodule Carddo.Games.Game do
  use Ecto.Schema
  import Ecto.Changeset

  schema "games" do
    field :name, :string
    field :description, :string
    field :state_machine, :map
    has_many :formats, Carddo.Games.Format

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:name, :description, :state_machine])
    |> validate_required([:name, :description])
  end
end
