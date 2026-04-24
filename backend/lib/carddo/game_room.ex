defmodule Carddo.GameRoom do
  use GenServer
  require Logger

  @default_timeout 30_000
  @default_ai_action_delay_ms 1500
  @default_ai_max_actions_per_turn 50
  @mvp_ai_weights %{"health" => 1, "power" => 1}

  defp ai_action_delay_ms,
    do: Application.get_env(:carddo, :ai_action_delay_ms, @default_ai_action_delay_ms)

  defp ai_max_actions_per_turn,
    do: Application.get_env(:carddo, :ai_max_actions_per_turn, @default_ai_max_actions_per_turn)

  # Public API

  def via_tuple(room_id), do: Carddo.Multiplayer.GameRegistry.via_tuple(room_id)

  def start_link(
        %{
          room_id: _room_id,
          game_id: _game_id,
          initial_state_json: _initial_state_json,
          solo_mode: _solo_mode,
          ai_player_id: _ai_player_id,
          player_order: _player_order
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
  def init(
        %{
          room_id: room_id,
          game_id: game_id,
          initial_state_json: initial_state_json,
          solo_mode: solo_mode,
          ai_player_id: ai_player_id,
          player_order: player_order
        } = opts
      ) do
    # Absolute 24-hour lifetime TTL — not an idle timer. Active rooms will also be
    # stopped after 24h. Converting this to an idle-TTL (reset on each move) is
    # tracked as a follow-up issue.
    ttl_id = make_ref()
    ttl_ref = Process.send_after(self(), {:ttl_expired, ttl_id}, :timer.hours(24))

    active_player_id =
      case player_order do
        [first | _] -> first
        _ -> nil
      end

    state = %{
      room_id: room_id,
      game_id: game_id,
      rust_state_json: initial_state_json,
      turn_number: 0,
      solo_mode: solo_mode,
      ai_player_id: ai_player_id,
      player_order: player_order,
      active_player_id: active_player_id,
      ai_actions_this_turn: 0,
      ai_action_delay_ms: Map.get(opts, :ai_action_delay_ms, ai_action_delay_ms()),
      ai_max_actions_per_turn: Map.get(opts, :ai_max_actions_per_turn, ai_max_actions_per_turn()),
      ended: false,
      ttl_ref: ttl_ref,
      ttl_id: ttl_id
    }

    {:ok, state, {:continue, :initial_checkpoint}}
  end

  @impl true
  def handle_continue(:initial_checkpoint, %{solo_mode: true} = state) do
    # Solo rooms are ephemeral by design — skip persistence so a crashed GenServer
    # can never rehydrate to a half-state missing its ai_player_id / player_order.
    {:noreply, state}
  end

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
    case apply_move(state, player_id, action_json) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason, new_state} -> {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state.rust_state_json, state}
  end

  @impl true
  def handle_call(:get_room_info, _from, state) do
    {:reply,
     %{
       game_id: state.game_id,
       state_json: state.rust_state_json,
       solo_mode: state.solo_mode,
       ai_player_id: state.ai_player_id,
       active_player_id: state.active_player_id,
       player_order: state.player_order
     }, state}
  end

  @impl true
  def handle_info(:ai_take_action, %{ended: true} = state), do: {:noreply, state}

  def handle_info(:ai_take_action, %{active_player_id: active, ai_player_id: ai} = state)
      when active != ai or is_nil(ai) do
    {:noreply, state}
  end

  def handle_info(:ai_take_action, state) do
    if state.ai_actions_this_turn >= state.ai_max_actions_per_turn do
      Logger.warning(
        "AI action cap reached (#{state.ai_max_actions_per_turn}), forcing EndTurn room=#{state.room_id}"
      )

      force_end_turn(state)
    else
      pick_and_apply_ai_action(state)
    end
  end

  def handle_info({:ttl_expired, id}, state) when id == state.ttl_id do
    Logger.info("GameRoom TTL expired for room=#{state.room_id}, cleaning up abandoned session")

    unless state.solo_mode do
      try do
        Carddo.Multiplayer.GameSessions.delete(state.room_id)
      rescue
        e ->
          Logger.error(
            "GameSessions delete exception (ttl) room=#{state.room_id}: #{Exception.message(e)}"
          )
      end
    end

    {:stop, :normal, state}
  end

  def handle_info({:ttl_expired, _stale_id}, state) do
    {:noreply, state}
  end

  defp pick_and_apply_ai_action(state) do
    case Carddo.Native.simulate_best_action(
           state.rust_state_json,
           state.ai_player_id,
           @mvp_ai_weights
         ) do
      {:ok, "null"} ->
        Logger.warning(
          "AI simulator returned no action, forcing EndTurn recovery room=#{state.room_id}"
        )

        force_end_turn(state)

      {:ok, action_json} ->
        case apply_move(state, state.ai_player_id, action_json) do
          {:ok, new_state} ->
            {:noreply, new_state}

          {:error, reason, _bad_state} ->
            Logger.error(
              "AI move failed room=#{state.room_id}: #{inspect(reason)}, forcing EndTurn recovery"
            )

            force_end_turn(state)
        end

      {:error, reason} ->
        Logger.error(
          "AI simulator failed room=#{state.room_id}: #{inspect(reason)}, forcing EndTurn recovery"
        )

        force_end_turn(state)
    end
  end

  defp force_end_turn(state) do
    case apply_move(state, state.ai_player_id, ~s("EndTurn")) do
      {:ok, new_state} ->
        {:noreply, new_state}

      {:error, reason, _bad_state} ->
        Logger.error(
          "AI recovery EndTurn failed room=#{state.room_id}: #{inspect(reason)} — room will rely on TTL cleanup"
        )

        {:noreply, state}
    end
  end

  defp apply_move(%{active_player_id: active} = state, player_id, _action_json)
       when active != nil and player_id != active do
    {:error, %{type: "not_active_player", message: "Not your turn"}, state}
  end

  defp apply_move(state, player_id, action_json) do
    case Carddo.Native.process_move(state.rust_state_json, action_json, player_id) do
      {:ok, new_state_json, _animations} ->
        case Jason.decode(new_state_json) do
          {:ok, decoded} ->
            turn_ended? = Map.get(decoded, "turn_ended") == true
            game_over_info = Map.get(decoded, "game_over")

            if game_over_info != nil do
              winner = game_over_info["winner"]
              # Always increment for the final checkpoint — the upsert guard is
              # `turn_number < ^new_turn`, so equal values are silently skipped.
              # Turn semantics are irrelevant once the game is over.
              new_turn = state.turn_number + 1

              maybe_async_checkpoint(state, new_state_json, new_turn)

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

              {:ok, new_state}
            else
              new_active =
                if turn_ended?, do: rotate_active_player(state), else: state.active_player_id

              new_state =
                if turn_ended? do
                  new_turn = state.turn_number + 1
                  maybe_async_checkpoint(state, new_state_json, new_turn)

                  %{
                    state
                    | rust_state_json: new_state_json,
                      turn_number: new_turn,
                      active_player_id: new_active,
                      ai_actions_this_turn: 0
                  }
                else
                  %{
                    state
                    | rust_state_json: new_state_json,
                      active_player_id: new_active,
                      ai_actions_this_turn: bump_ai_counter(state, player_id, turn_ended?)
                  }
                end

              broadcast(state.room_id, "state_resolved", %{
                state: new_state_json,
                active_player_id: new_active
              })

              maybe_schedule_ai(new_state)
              {:ok, new_state}
            end

          {:error, decode_error} ->
            Logger.error(
              "Failed to decode game state JSON in Carddo.GameRoom: #{inspect(decode_error)}"
            )

            {:error, %{type: "invalid_state", message: "Failed to decode game state"}, state}
        end

      {:error, reason, _animations} ->
        Logger.error("Native error in Carddo.Native.process_move: #{inspect(reason)}")

        {:error, %{type: "native_error", message: "Failed to process move. Please try again."},
         state}
    end
  end

  defp bump_ai_counter(%{ai_player_id: ai} = state, player_id, false) when ai == player_id do
    state.ai_actions_this_turn + 1
  end

  defp bump_ai_counter(state, _player_id, _turn_ended?), do: state.ai_actions_this_turn

  defp rotate_active_player(%{player_order: order, active_player_id: current})
       when is_list(order) and length(order) > 0 do
    case Enum.find_index(order, &(&1 == current)) do
      nil -> current
      idx -> Enum.at(order, rem(idx + 1, length(order)))
    end
  end

  defp rotate_active_player(%{active_player_id: current}), do: current

  defp maybe_schedule_ai(
         %{
           solo_mode: true,
           ended: false,
           ai_player_id: ai_id,
           active_player_id: ai_id
         } = state
       )
       when not is_nil(ai_id) do
    Process.send_after(self(), :ai_take_action, state.ai_action_delay_ms)
    :ok
  end

  defp maybe_schedule_ai(_state), do: :ok

  defp broadcast(room_id, event, payload) do
    CarddoWeb.Endpoint.broadcast("room:#{room_id}", event, payload)
  end

  defp maybe_async_checkpoint(%{solo_mode: true}, _state_json, _turn_number), do: :ok

  defp maybe_async_checkpoint(state, state_json, turn_number) do
    async_checkpoint(state.room_id, state.game_id, state_json, turn_number)
  end

  defp async_checkpoint(room_id, game_id, state_json, turn_number) do
    Task.start(fn ->
      try do
        case Carddo.Multiplayer.GameSessions.upsert(
               room_id,
               game_id,
               state_json,
               turn_number
             ) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            Logger.error("GameSessions.upsert failed room=#{room_id}: #{inspect(reason)}")
        end
      rescue
        e ->
          Logger.error("GameSessions.upsert exception room=#{room_id}: #{Exception.message(e)}")
      end
    end)
  end
end
