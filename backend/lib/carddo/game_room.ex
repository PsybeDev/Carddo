defmodule Carddo.GameRoom do
  use GenServer
  require Logger

  @default_timeout 30_000

  # Public API

  def via_tuple(room_id), do: Carddo.Multiplayer.GameRegistry.via_tuple(room_id)

  def start_link(
        %{
          room_id: _room_id,
          game_id: _game_id,
          initial_state_json: _initial_state_json,
          solo_mode: _solo_mode
        } = opts
      ) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple(opts.room_id))
  end

  def start_link(bad_opts) when is_map(bad_opts) do
    {:error, {:invalid_options, Map.keys(bad_opts)}}
  end

  def start_link(_bad_opts) do
    {:error, {:invalid_options, :not_a_map}}
  end

  def make_move(room_id, player_id, action_json, timeout \\ @default_timeout) do
    GenServer.call(via_tuple(room_id), {:make_move, player_id, action_json}, timeout)
  end

  def get_state(room_id, timeout \\ @default_timeout) do
    GenServer.call(via_tuple(room_id), :get_state, timeout)
  end

  # GenServer callbacks

  @impl true
  def init(%{
        room_id: room_id,
        game_id: game_id,
        initial_state_json: initial_state_json,
        solo_mode: solo_mode
      }) do
    state = %{
      room_id: room_id,
      game_id: game_id,
      rust_state_json: initial_state_json,
      turn_number: 0,
      solo_mode: solo_mode,
      ended: false
    }

    Task.start(fn ->
      Carddo.Multiplayer.GameSessions.upsert(room_id, game_id, initial_state_json, 0)
    end)

    Process.send_after(self(), :ttl_expired, :timer.hours(24))

    {:ok, state}
  end

  @impl true
  def handle_call({:make_move, _player_id, _action_json}, _from, %{ended: true} = state) do
    {:reply, {:error, %{type: "game_over", message: "Game has ended"}}, state}
  end

  def handle_call({:make_move, player_id, action_json}, _from, state) do
    end_turn? = match?({:ok, "EndTurn"}, Jason.decode(action_json))

    case Carddo.Native.process_move(state.rust_state_json, action_json, player_id) do
      {:ok, new_state_json, _animations} ->
        case Jason.decode(new_state_json) do
          {:ok, decoded} ->
            game_over? = Map.get(decoded, "game_over") == true

            {event, new_state} =
              cond do
                game_over? ->
                  Task.start(fn ->
                    Carddo.Multiplayer.GameSessions.delete(state.room_id)
                  end)

                  {"game_over", %{state | rust_state_json: new_state_json, ended: true}}

                end_turn? ->
                  new_turn = state.turn_number + 1

                  Task.start(fn ->
                    case Carddo.Multiplayer.GameSessions.upsert(
                           state.room_id,
                           state.game_id,
                           new_state_json,
                           new_turn
                         ) do
                      {:ok, _} ->
                        :ok

                      {:error, reason} ->
                        Logger.error(
                          "GameSessions.upsert failed room=#{state.room_id}: #{inspect(reason)}"
                        )
                    end
                  end)

                  {"state_resolved",
                   %{state | rust_state_json: new_state_json, turn_number: new_turn}}

                true ->
                  {"state_resolved", %{state | rust_state_json: new_state_json}}
              end

            broadcast(state.room_id, event, %{state: new_state_json})
            {:reply, :ok, new_state}

          {:error, decode_error} ->
            Logger.error(
              "Failed to decode game state JSON in Carddo.GameRoom: #{inspect(decode_error)}"
            )

            {:reply, {:error, %{type: "invalid_state", message: "Failed to decode game state"}},
             state}
        end

      {:error, reason, _animations} ->
        Logger.error("Native error in Carddo.Native.process_move: #{inspect(reason)}")

        {:reply,
         {:error, %{type: "native_error", message: "Failed to process move. Please try again."}},
         state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state.rust_state_json, state}
  end

  @impl true
  def handle_info(:ttl_expired, state) do
    Logger.info("GameRoom TTL expired for room=#{state.room_id}, cleaning up abandoned session")
    Carddo.Multiplayer.GameSessions.delete(state.room_id)
    {:stop, :normal, state}
  end

  defp broadcast(room_id, event, payload) do
    CarddoWeb.Endpoint.broadcast("room:#{room_id}", event, payload)
  end
end
