defmodule Carddo.Multiplayer do
  alias Carddo.{GameRoom, GameRegistry, RoomSupervisor}

  def start_room(room_id, game_id, initial_state_json, solo_mode \\ false) do
    DynamicSupervisor.start_child(
      RoomSupervisor,
      {GameRoom,
       %{
         room_id: room_id,
         game_id: game_id,
         initial_state_json: initial_state_json,
         solo_mode: solo_mode
       }}
    )
  end

  def room_exists?(room_id) do
    GameRegistry.lookup(room_id) != []
  end
end
