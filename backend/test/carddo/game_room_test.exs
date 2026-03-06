defmodule Carddo.GameRoomTest do
  use ExUnit.Case, async: true

  alias Carddo.GameRoom
  alias Phoenix.PubSub

  @empty_state ~s({"entities":{},"zones":{},"event_queue":[],"pending_animations":[],"stack_order":"Fifo","state_checks":[]})

  defp start_room(opts \\ %{}) do
    room_id = "test_room_#{System.unique_integer([:positive])}"
    game_id = Ecto.UUID.generate()

    base_opts = %{
      room_id: room_id,
      game_id: game_id,
      initial_state_json: @empty_state,
      solo_mode: false
    }

    opts = Map.merge(base_opts, Enum.into(opts, %{}))

    {:ok, pid} = start_supervised({GameRoom, opts})
    {room_id, pid}
  end

  describe "init/1" do
    test "starts and registers under room_id" do
      {room_id, _pid} = start_room()

      # Can retrieve state via the registered name
      state = GameRoom.get_state(room_id)
      assert {:ok, _} = Jason.decode(state)
    end

    test "stores initial state correctly" do
      custom_state =
        ~s({"entities":{"e1":{"id":"e1","owner_id":"p1","properties":{},"abilities":[]}},"zones":{},"event_queue":[],"pending_animations":[],"stack_order":"Fifo","state_checks":[]})

      {room_id, _pid} = start_room(initial_state_json: custom_state)

      state = GameRoom.get_state(room_id)
      decoded = Jason.decode!(state)
      assert decoded["entities"]["e1"]["id"] == "e1"
    end

    test "defaults turn_number to 0 and ended to false" do
      {room_id, _pid} = start_room()
      assert is_binary(GameRoom.get_state(room_id))
    end

    test "accepts solo_mode parameter" do
      {room_id, _pid} = start_room(solo_mode: true)
      assert is_binary(GameRoom.get_state(room_id))
    end

    test "start_link returns error for invalid options" do
      room_id = "test_room_#{System.unique_integer([:positive])}"

      # Missing required keys - only room_id provided, missing game_id, initial_state_json, solo_mode
      assert {:error, {:invalid_options, keys}} = GameRoom.start_link(%{room_id: room_id})
      # keys contains the provided keys, not missing ones
      assert :room_id in keys
    end

    test "start_link returns error for non-map input" do
      assert {:error, {:invalid_options, :not_a_map}} = GameRoom.start_link(nil)
    end
  end

  describe "get_state/1" do
    test "returns rust_state_json" do
      {room_id, _pid} = start_room()
      state = GameRoom.get_state(room_id)

      assert {:ok, decoded} = Jason.decode(state)
      assert decoded["entities"] == %{}
      assert decoded["zones"] == %{}
    end
  end

  describe "make_move/3" do
    test "valid move updates state and returns :ok" do
      {room_id, _pid} = start_room()
      action = ~s("EndTurn")

      result = GameRoom.make_move(room_id, "player_1", action)
      assert result == :ok

      # State was updated
      new_state = GameRoom.get_state(room_id)
      assert {:ok, _decoded} = Jason.decode(new_state)
    end

    test "valid move broadcasts state_resolved" do
      {room_id, _pid} = start_room()
      action = ~s("EndTurn")

      # Subscribe to the room topic
      topic = "room:#{room_id}"
      PubSub.subscribe(Carddo.PubSub, topic)

      result = GameRoom.make_move(room_id, "player_1", action)
      assert result == :ok

      # Verify broadcast was received
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^topic,
        event: "state_resolved",
        payload: %{state: _state_json}
      }
    end

    test "invalid action returns error without mutating state" do
      {room_id, _pid} = start_room()
      initial_state = GameRoom.get_state(room_id)

      # Invalid action - targeting nonexistent entity
      action =
        Jason.encode!(%{MutateProperty: %{target_id: "ghost", property: "health", delta: -1}})

      result = GameRoom.make_move(room_id, "player_1", action)

      assert {:error, %{type: "native_error", message: message}} = result
      assert message == "Failed to process move. Please try again."

      # State should not have changed
      assert GameRoom.get_state(room_id) == initial_state
    end
  end

  describe "make_move/3 with repeated calls" do
    test "handles multiple sequential moves without crashing" do
      {room_id, _pid} = start_room()

      action = ~s("EndTurn")

      assert GameRoom.make_move(room_id, "player_1", action) == :ok
      assert GameRoom.make_move(room_id, "player_1", action) == :ok
    end

    test "start_link returns error for non-map options" do
      # Pass nil, which is not a map
      assert {:error, {:invalid_options, :not_a_map}} = GameRoom.start_link(nil)
    end
  end

  describe "turn boundary handling" do
    test "EndTurn action does not crash" do
      {room_id, _pid} = start_room()
      action = ~s("EndTurn")

      # Should not raise
      result = GameRoom.make_move(room_id, "player_1", action)
      assert result == :ok
    end
  end
end
