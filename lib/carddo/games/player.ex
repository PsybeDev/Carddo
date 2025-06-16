defmodule Carddo.Games.GamePlayer do
  use Ecto.Schema
  import Ecto.Changeset

  schema "games_players" do
    field :hand, {:array, :map}, default: []
    field :deck, {:array, :map}, default: []
    field :discard_pile, {:array, :map}, default: []
    field :play_area, {:array, :map}, default: []
    field :mana, :integer, default: 0
    field :life_points, :integer, default: 20
    belongs_to :user, Carddo.Accounts.User
    belongs_to :game_session, Carddo.Games.GameSession

    timestamps(type: :utc_datetime)
  end

  def changeset(game_player, attrs) do
    game_player
    |> cast(attrs, [:hand, :deck, :discard_pile, :play_area, :mana, :user_id, :game_session_id, :life_points])
    |> validate_required([:hand, :deck, :discard_pile, :play_area, :mana, :user_id, :game_session_id])
    |> assoc_constraint(:user)
    |> assoc_constraint(:game_session)
  end

end
