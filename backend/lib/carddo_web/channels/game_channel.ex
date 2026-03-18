defmodule CarddoWeb.GameChannel do
  @moduledoc """
  Routes WebSocket messages between Svelte clients and `GameRoom` GenServers.

  This is a thin routing layer (ADR-002) — no game logic, no Repo calls.
  Handles join/resume, action dispatch, and error pushes.
  """

  use Phoenix.Channel
  require Logger

  alias Carddo.{Games, Multiplayer}
  alias Carddo.Multiplayer.{GameInitializer, GameSessions}
  alias Carddo.GameRoom

  @impl true
  def join("room:" <> room_id, %{"game_id" => game_id, "deck_id" => deck_id}, socket) do
    current_user = socket.assigns.current_user
    player_id = to_string(current_user.id)

    with {:ok, %{game_id: room_game_id, state_json: state_json}} <-
           resolve_room_boot(room_id, game_id, player_id, deck_id),
         {:ok, _game} <- authorize_game(room_game_id, current_user),
         :ok <- ensure_room_started(room_id, room_game_id, state_json) do
      {:ok, %{state: state_json}, assign(socket, :room_id, room_id)}
    else
      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  def join("room:" <> _room_id, _params, _socket) do
    {:error, %{reason: "Missing required params: game_id, deck_id"}}
  end

  @impl true
  def handle_in(
        "submit_action",
        %{"client_sequence_id" => seq_id, "action" => action},
        socket
      ) do
    room_id = socket.assigns.room_id
    player_id = to_string(socket.assigns.current_user.id)

    # Phoenix decodes JSON payloads; the NIF expects a JSON string.
    action_json = Jason.encode!(action)

    result =
      try do
        GameRoom.make_move(room_id, player_id, action_json)
      catch
        :exit, reason ->
          Logger.error("GameRoom.make_move crashed room=#{room_id}: #{inspect(reason)}")
          {:error, %{type: "room_unavailable", message: "Game room is unavailable"}}
      end

    case result do
      :ok ->
        {:noreply, socket}

      {:error, %{type: type, message: msg}} ->
        push(socket, "action_rejected", %{
          client_sequence_id: seq_id,
          error: %{type: type, message: msg}
        })

        {:noreply, socket}
    end
  end

  def handle_in(event, _payload, socket) do
    Logger.warning("GameChannel received unknown event: #{event}")
    {:reply, {:error, %{reason: "unknown_event"}}, socket}
  end

  defp authorize_game(game_id, current_user) do
    case Games.get_game(game_id) do
      nil -> {:error, "Game not found"}
      game when game.owner_id == current_user.id -> {:ok, game}
      _game -> {:error, "Forbidden"}
    end
  end

  defp resolve_room_boot(room_id, requested_game_id, player_id, deck_id) do
    case GameSessions.get(room_id) do
      nil ->
        with {:ok, state_json} <- GameInitializer.build(requested_game_id, [{player_id, deck_id}]) do
          {:ok, %{game_id: requested_game_id, state_json: state_json}}
        end

      session ->
        if to_string(session.game_id) == to_string(requested_game_id) do
          {:ok, %{game_id: session.game_id, state_json: Jason.encode!(session.state_json)}}
        else
          {:error, "Room/game mismatch"}
        end
    end
  end

  defp ensure_room_started(room_id, game_id, state_json) do
    if Multiplayer.room_exists?(room_id) do
      :ok
    else
      case Multiplayer.start_room(room_id, game_id, state_json) do
        {:ok, _pid} ->
          :ok

        {:error, {:already_started, _pid}} ->
          :ok

        {:error, reason} ->
          Logger.error("Failed to start room #{room_id}: #{inspect(reason)}")
          {:error, "Failed to start game room"}
      end
    end
  end
end
