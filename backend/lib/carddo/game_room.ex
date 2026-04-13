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

  def get_room_info(room_id, timeout \\ @default_timeout) do
    GenServer.call(via_tuple(room_id), :get_room_info, timeout)
  end

  # GenServer callbacks

  @impl true
  def init(%{
        room_id: room_id,
        game_id: game_id,
        initial_state_json: initial_state_json,
        solo_mode: solo_mode
      }) do
    # Absolute 24-hour lifetime TTL — not an idle timer. Active rooms will also be
    # stopped after 24h. Converting this to an idle-TTL (reset on each move) is
    # tracked as a follow-up issue.
    ttl_id = make_ref()
    ttl_ref = Process.send_after(self(), {:ttl_expired, ttl_id}, :timer.hours(24))

    state = %{
      room_id: room_id,
      game_id: game_id,
      rust_state_json: initial_state_json,
      turn_number: 0,
      solo_mode: solo_mode,
      ended: false,
      ttl_ref: ttl_ref,
      ttl_id: ttl_id
    }

    {:ok, state, {:continue, :initial_checkpoint}}
  end

  @impl true
  def handle_continue(:initial_checkpoint, state) do
    try do
      case Carddo.Multiplayer.GameSessions.upsert(
             state.room_id,
             state.game_id,
             state.rust_state_json,
             0
           ) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          Logger.error(
            "GameSessions initial checkpoint failed room=#{state.room_id}: #{inspect(reason)}"
          )
      end
    rescue
      e ->
        Logger.error(
          "GameSessions initial checkpoint exception room=#{state.room_id}: #{Exception.message(e)}"
        )
    end

    {:noreply, state}
  end

  @impl true
  def handle_call({:make_move, _player_id, _action_json}, _from, %{ended: true} = state) do
    {:reply, {:error, %{type: "game_over", message: "Game has ended"}}, state}
  end

  def handle_call({:make_move, player_id, action_json}, _from, state) do
    case Carddo.Native.process_move(state.rust_state_json, action_json, player_id) do
      {:ok, new_state_json, _animations} ->
        case Jason.decode(new_state_json) do
          {:ok, decoded} ->
            turn_ended? = Map.get(decoded, "turn_ended") == true
            game_over_info = Map.get(decoded, "game_over")

            if game_over_info != nil do
              winner = game_over_info["winner"]
              new_turn = if turn_ended?, do: state.turn_number + 1, else: state.turn_number

              Task.start(fn ->
                try do
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
                rescue
                  e ->
                    Logger.error(
                      "GameSessions.upsert exception room=#{state.room_id}: #{Exception.message(e)}"
                    )
                end
              end)

              broadcast(state.room_id, "game_over", %{
                winner_id: winner,
                final_state: new_state_json
              })

              Process.cancel_timer(state.ttl_ref)
              new_ttl_id = make_ref()

              new_ttl_ref =
                Process.send_after(self(), {:ttl_expired, new_ttl_id}, :timer.minutes(5))

              new_state = %{
                state
                | rust_state_json: new_state_json,
                  ended: true,
                  ttl_ref: new_ttl_ref,
                  ttl_id: new_ttl_id,
                  turn_number: new_turn
              }

              {:reply, :ok, new_state}
            else
              {event, new_state} =
                if turn_ended? do
                  new_turn = state.turn_number + 1

                  Task.start(fn ->
                    try do
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
                    rescue
                      e ->
                        Logger.error(
                          "GameSessions.upsert exception room=#{state.room_id}: #{Exception.message(e)}"
                        )
                    end
                  end)

                  {"state_resolved",
                   %{state | rust_state_json: new_state_json, turn_number: new_turn}}
                else
                  {"state_resolved", %{state | rust_state_json: new_state_json}}
                end

              broadcast(state.room_id, event, %{state: new_state_json})
              {:reply, :ok, new_state}
            end

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
  def handle_call(:get_room_info, _from, state) do
    {:reply, %{game_id: state.game_id, state_json: state.rust_state_json}, state}
  end

  @impl true
  def handle_info({:ttl_expired, id}, state) when id == state.ttl_id do
    Logger.info("GameRoom TTL expired for room=#{state.room_id}, cleaning up abandoned session")

    try do
      Carddo.Multiplayer.GameSessions.delete(state.room_id)
    rescue
      e ->
        Logger.error(
          "GameSessions delete exception (ttl) room=#{state.room_id}: #{Exception.message(e)}"
        )
    end

    {:stop, :normal, state}
  end

  def handle_info({:ttl_expired, _stale_id}, state) do
    {:noreply, state}
  end

  defp broadcast(room_id, event, payload) do
    CarddoWeb.Endpoint.broadcast("room:#{room_id}", event, payload)
  end
end
