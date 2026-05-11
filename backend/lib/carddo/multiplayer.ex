defmodule Carddo.Multiplayer do
  @callback start_room(map()) :: {:ok, pid()} | {:error, term()}
  @callback room_exists?(String.t()) :: boolean()

  alias Carddo.GameRoom
  alias Carddo.Multiplayer.{GameRegistry, RoomSupervisor}

  def start_room(%{room_id: _, game_id: _, initial_state_json: _} = opts) do
    opts =
      opts
      |> Map.put_new(:solo_mode, false)
      |> Map.put_new(:ai_player_id, nil)
      |> Map.put_new(:player_order, [])

    DynamicSupervisor.start_child(
      RoomSupervisor,
      Supervisor.child_spec({GameRoom, opts}, restart: :temporary)
    )
  end

  def room_exists?(room_id) do
    case GameRegistry.lookup(room_id) do
      [{pid, _value} | _rest] -> Process.alive?(pid)
      _ -> false
    end
  end
end
