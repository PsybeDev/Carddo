defmodule Carddo.Multiplayer do
  @callback start_room(String.t(), integer(), String.t(), boolean()) ::
              {:ok, pid()} | {:error, term()}
  @callback room_exists?(String.t()) :: boolean()

  alias Carddo.GameRoom
  alias Carddo.Multiplayer.{GameRegistry, RoomSupervisor}

  def start_room(room_id, game_id, initial_state_json, solo_mode \\ false) do
    DynamicSupervisor.start_child(
      RoomSupervisor,
      Supervisor.child_spec(
        {GameRoom,
         %{
           room_id: room_id,
           game_id: game_id,
           initial_state_json: initial_state_json,
           solo_mode: solo_mode
         }},
        restart: :temporary
      )
    )
  end

  def room_exists?(room_id) do
    case GameRegistry.lookup(room_id) do
      [{pid, _value} | _rest] -> Process.alive?(pid)
      _ -> false
    end
  end
end
