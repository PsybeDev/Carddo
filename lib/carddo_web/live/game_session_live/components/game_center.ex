defmodule CarddoWeb.GameSessionLive.Components.GameCenterComponent do
  use CarddoWeb, :live_component

  alias Carddo.Games

  def render(assigns) do
    ~H"""
    <div class="game-center-panel bg-jet-800 rounded-lg p-6 shadow-xl">
      <div class="turn-info text-center mb-4">
        <h2 class="text-xl font-bold text-pearl">
          Turn <%= @game_session.current_turn %>
        </h2>
        <p class="text-cool_gray">
          <%= current_player_name(@game_session) %>'s Turn
        </p>
      </div>

      <div class="game-actions flex gap-4 justify-center">
        <button
          class="btn btn-primary"
          phx-click="draw_card"
        >
          Draw Card
        </button>
        <button
          class="btn btn-secondary"
          phx-click="end_turn"
        >
          End Turn
        </button>
      </div>
    </div>
    """
  end

  defp current_player_name(game_session) do
    # Implementation to get current player name
    Games.get_current_player(game_session)
    |> case do
      nil -> "Unknown Player"
      player -> player.user.username || "Unnamed Player"
    end
  end
end
