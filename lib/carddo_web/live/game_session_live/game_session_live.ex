defmodule CarddoWeb.GameSessionLive.GameSessionLive do
  use CarddoWeb, :live_view
  alias Carddo.Games
  alias CarddoWeb.GameSessionLive.Components

  def mount(%{"id" => game_session_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Carddo.PubSub, "game_session:#{game_session_id}")
    end

    game_session = Games.get_game_session!(game_session_id)
    current_player = Games.get_player_for_session(game_session, socket.assigns.current_user)

    {:ok,
     socket
     |> assign(:game_session, game_session)
     |> assign(:current_player, current_player)
     |> assign(:players, Games.list_players_for_session(game_session))}
  end

  def render(assigns) do
    ~H"""
    <div class="game-board min-h-screen bg-gradient-to-b from-davys_gray-800 to-jet">
      <!-- Opponent's area -->
      <div class="opponent-area p-4">
        <.live_component
          module={Components.PlayerAreaComponent}
          id="opponent-area"
          player={get_opponent(@players, @current_player) || @current_player}
          is_current_player={false}
        />
      </div>

      <!-- Game center area -->
      <div class="game-center flex justify-center items-center py-8">
        <.live_component
          module={Components.GameCenterComponent}
          id="game-center"
          game_session={@game_session}
        />
      </div>

      <!-- Current player's area -->
      <div class="current-player-area p-4">
        <.live_component
          module={Components.PlayerAreaComponent}
          id="current-player-area"
          player={@current_player}
          is_current_player={true}
        />
      </div>
    </div>
    """
  end

  def handle_event("play_card", %{"card_id" => card_id}, socket) do
    # Handle card play logic
    game_session = socket.assigns.game_session
    current_player = socket.assigns.current_player
    case Games.play_card(game_session.id, current_player.id, card_id) do
      {:ok, updated_game_session} ->
        Phoenix.PubSub.broadcast(Carddo.PubSub, "game_session:#{game_session.id}", {:game_updated, updated_game_session})
        {:noreply, assign(socket, :game_session, updated_game_session)}
      {:error, _reason} ->
        # Handle error (e.g., show a flash message)
        {:noreply, socket}
    end
    {:noreply, socket}
  end

  def handle_event("end_turn", _params, socket) do
    # Handle end turn logic
    {:noreply, socket}
  end

  def handle_info({:game_updated, game_session}, socket) do
    {:noreply, assign(socket, :game_session, game_session)}
  end

  defp get_opponent(players, current_player) do
    Enum.find(players, fn player -> player.id != current_player.id end)
  end
end
