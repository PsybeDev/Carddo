defmodule CarddoWeb.GameChannel do
  @moduledoc """
  Routes WebSocket messages between Svelte clients and `GameRoom` GenServers.

  Thin routing layer (ADR-002) — no game logic. Auth and state resolution
  delegate to context modules; no direct Repo access.

  Error payloads follow the CAR-60 envelope: `%{errors: [%{message, code}]}`.
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

    with {:ok, _game} <- authorize_game(game_id, current_user),
         {:ok, %{game_id: room_game_id, state_json: state_json}} <-
           resolve_room_boot(room_id, game_id, player_id, deck_id),
         :ok <- ensure_room_started(room_id, room_game_id, state_json) do
      {:ok, %{state: state_json}, assign(socket, :room_id, room_id)}
    else
      {:error, {code, message}} ->
        {:error, error_envelope(message, code)}
    end
  end

  def join("room:" <> _room_id, _params, _socket) do
    {:error, error_envelope("Missing required params: game_id, deck_id", "missing_params")}
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
          errors: [%{message: msg, code: type}]
        })

        {:noreply, socket}
    end
  end

  def handle_in("submit_action", _payload, socket) do
    {:reply,
     {:error,
      error_envelope(
        "Invalid payload: requires client_sequence_id and action",
        "invalid_payload"
      )}, socket}
  end

  def handle_in(event, _payload, socket) do
    Logger.warning("GameChannel received unknown event: #{event}")
    {:reply, {:error, error_envelope("Unknown event", "unknown_event")}, socket}
  end

  defp error_envelope(message, code), do: %{errors: [%{message: message, code: code}]}

  defp authorize_game(game_id, current_user) when is_integer(game_id) do
    case Games.get_game(game_id) do
      nil -> {:error, {"not_found", "Game not found"}}
      game when game.owner_id == current_user.id -> {:ok, game}
      _game -> {:error, {"forbidden", "Forbidden"}}
    end
  end

  defp authorize_game(_game_id, _current_user),
    do: {:error, {"invalid_game_id", "Invalid game_id"}}

  defp resolve_room_boot(room_id, requested_game_id, player_id, deck_id) do
    case fetch_live_room(room_id) do
      {:ok, info} ->
        if to_string(info.game_id) == to_string(requested_game_id) do
          {:ok, info}
        else
          {:error, {"room_game_mismatch", "Room/game mismatch"}}
        end

      :not_running ->
        case GameSessions.get(room_id) do
          nil ->
            case GameInitializer.build(requested_game_id, [{player_id, deck_id}]) do
              {:ok, state_json} ->
                {:ok, %{game_id: requested_game_id, state_json: state_json}}

              {:error, reason} ->
                {:error, {"init_failed", reason}}
            end

          session ->
            if to_string(session.game_id) == to_string(requested_game_id) do
              {:ok, %{game_id: session.game_id, state_json: Jason.encode!(session.state_json)}}
            else
              {:error, {"room_game_mismatch", "Room/game mismatch"}}
            end
        end
    end
  end

  defp fetch_live_room(room_id) do
    {:ok, GameRoom.get_room_info(room_id)}
  catch
    :exit, _ -> :not_running
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
          {:error, {"room_start_failed", "Failed to start game room"}}
      end
    end
  end
end
