defmodule Carddo.Games.GameSession do
  use Ecto.Schema
  import Ecto.Changeset

  schema "game_sessions" do
    field :state, :string, default: "pending"
    field :current_turn, :integer, default: 0
    field :current_player_id, :integer
    field :game_data, :map, default: %{}
    belongs_to :game, Carddo.Games.Game
    belongs_to :format, Carddo.Games.Format
    has_many :players, Carddo.Games.GamePlayer

    timestamps(type: :utc_datetime)
  end

  def changeset(game_session, attrs) do
    game_session
    |> cast(attrs, [:state, :current_turn, :current_player_id, :game_data])
    |> validate_required([:state, :current_turn])
    |> validate_inclusion(:state, ["pending", "active", "finished"])
    |> validate_number(:current_turn, greater_than_or_equal_to: 0)
  end

end
