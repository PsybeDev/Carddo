defmodule Carddo.Games.Format do
  use Ecto.Schema
  import Ecto.Changeset

  schema "formats" do
    field :name, :string
    field :description, :string
    field :state_machine, :map
    belongs_to :game, Carddo.Games.Game

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(format, attrs) do
    format
    |> cast(attrs, [:name, :description, :state_machine])
    |> validate_required([:name, :description])
  end
end
