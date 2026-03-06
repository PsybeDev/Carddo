defmodule Carddo.GameRoom do
  use GenServer
  require Logger

  # Public API

  def via_tuple(room_id), do: {:via, Registry, {Carddo.GameRegistry, room_id}}

  def start_link(%{room_id: _room_id} = opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple(opts.room_id))
  end

  def make_move(room_id, player_id, action_json) do
    GenServer.call(via_tuple(room_id), {:make_move, player_id, action_json})
  end

  def get_state(room_id) do
    GenServer.call(via_tuple(room_id), :get_state)
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

    {:ok, state}
  end

  @impl true
  def handle_call({:make_move, _player_id, _action_json}, _from, %{ended: true} = state) do
    {:reply, {:error, %{type: "game_over", message: "Game has ended"}}, state}
  end

  def handle_call({:make_move, player_id, action_json}, _from, state) do
    case Carddo.Native.process_move(state.rust_state_json, action_json, player_id) do
      {:ok, new_state_json} ->
        decoded = Jason.decode!(new_state_json)

        new_state =
          if Map.has_key?(decoded, "game_over") do
            CarddoWeb.Endpoint.broadcast!("room:#{state.room_id}", "game_over", %{
              state: new_state_json
            })

            %{state | rust_state_json: new_state_json, ended: true}
          else
            if get_in(decoded, ["turn", "phase"]) == "end" do
              new_turn = state.turn_number + 1
              game_id = state.game_id

              Task.async(fn ->
                Logger.info("CAR-63 TODO: checkpoint game_id=#{game_id}, turn=#{new_turn}")
              end)

              CarddoWeb.Endpoint.broadcast!("room:#{state.room_id}", "state_resolved", %{
                state: new_state_json
              })

              %{state | rust_state_json: new_state_json, turn_number: new_turn}
            else
              CarddoWeb.Endpoint.broadcast!("room:#{state.room_id}", "state_resolved", %{
                state: new_state_json
              })

              %{state | rust_state_json: new_state_json}
            end
          end

        {:reply, :ok, new_state}

      {:error, type, message} ->
        {:reply, {:error, %{type: type, message: message}}, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state.rust_state_json, state}
  end

  # Ignore Task results from async checkpoints
  @impl true
  def handle_info({ref, _result}, state) when is_reference(ref) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end
end
