defmodule CarddoWeb.GameChannel do
  use CarddoWeb, :channel
  alias Carddo.Games

  @impl true
  def join("game_session:" <> game_session_id, _payload, socket) do
    game_session = Games.get_game_session!(game_session_id)

    # Verify user is part of this game session
    if Games.user_in_session?(game_session, socket.assigns.user_id) do
      {:ok, assign(socket, :game_session_id, game_session_id)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("play_card", %{"card_id" => card_id}, socket) do
    game_session_id = socket.assigns.game_session_id
    user_id = socket.assigns.user_id

    case Games.play_card(game_session_id, user_id, card_id) do
      {:ok, updated_session} ->
        broadcast(socket, "game_updated", %{game_session: updated_session})
        {:reply, :ok, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  @impl true
  def handle_in("end_turn", _payload, socket) do
    game_session_id = socket.assigns.game_session_id
    user_id = socket.assigns.user_id

    case Games.end_turn(game_session_id, user_id) do
      {:ok, updated_session} ->
        broadcast(socket, "game_updated", %{game_session: updated_session})
        {:reply, :ok, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end
end
