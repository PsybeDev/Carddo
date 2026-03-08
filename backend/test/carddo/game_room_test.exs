defmodule Carddo.GameRoomTest do
  # async: false so the SQL sandbox runs in shared mode, allowing background
  # Task.start processes (spawned by GameRoom.init for DB checkpointing) to
  # access the DB connection without OwnershipErrors.
  use Carddo.DataCase, async: false

  alias Carddo.{Game, GameRoom, Repo, User}
  alias Phoenix.PubSub

  @empty_state ~s({"entities":{},"zones":{},"event_queue":[],"pending_animations":[],"stack_order":"Fifo","state_checks":[]})

  setup do
    {:ok, user} =
      %User{}
      |> User.changeset(%{email: "room-#{System.unique_integer([:positive])}@example.com"})
      |> Repo.insert()

    {:ok, game} =
      Ecto.build_assoc(user, :games)
      |> Game.changeset(%{title: "Test Game"})
      |> Repo.insert()

    %{game: game}
  end

  # Polls `fun` every 20ms until it returns a non-nil value or `timeout_ms` elapses.
  # Use this instead of Process.sleep when waiting for background Task.start DB writes.
  defp wait_for(fun, timeout_ms \\ 500) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    wait_for_loop(fun, deadline)
  end

  defp wait_for_loop(fun, deadline) do
    case fun.() do
      nil ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(20)
          wait_for_loop(fun, deadline)
        else
          nil
        end

      result ->
        result
    end
  end

  defp start_room(game, opts \\ %{}) do
    room_id = "test_room_#{System.unique_integer([:positive])}"

    base_opts = %{
      room_id: room_id,
      game_id: game.id,
      initial_state_json: @empty_state,
      solo_mode: false
    }

    opts = Map.merge(base_opts, Enum.into(opts, %{}))

    {:ok, pid} = start_supervised({GameRoom, opts})
    {room_id, pid}
  end

  describe "init/1" do
    test "starts and registers under room_id", %{game: game} do
      {room_id, _pid} = start_room(game)

      # Can retrieve state via the registered name
      state = GameRoom.get_state(room_id)
      assert {:ok, _} = Jason.decode(state)
    end

    test "stores initial state correctly", %{game: game} do
      custom_state =
        ~s({"entities":{"e1":{"id":"e1","owner_id":"p1","template_id":"t1","properties":{},"abilities":[]}},"zones":{},"event_queue":[],"pending_animations":[],"stack_order":"Fifo","state_checks":[]})

      {room_id, _pid} = start_room(game, initial_state_json: custom_state)

      state = GameRoom.get_state(room_id)
      decoded = Jason.decode!(state)
      assert decoded["entities"]["e1"]["id"] == "e1"
    end

    test "initial state is returned as a JSON string", %{game: game} do
      {room_id, _pid} = start_room(game)
      assert is_binary(GameRoom.get_state(room_id))
    end

    test "accepts solo_mode parameter", %{game: game} do
      {room_id, _pid} = start_room(game, solo_mode: true)
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
    test "returns rust_state_json", %{game: game} do
      {room_id, _pid} = start_room(game)
      state = GameRoom.get_state(room_id)

      assert {:ok, decoded} = Jason.decode(state)
      assert decoded["entities"] == %{}
      assert decoded["zones"] == %{}
    end
  end

  describe "make_move/3" do
    test "valid move updates state and returns :ok", %{game: game} do
      {room_id, _pid} = start_room(game)
      action = ~s("EndTurn")

      result = GameRoom.make_move(room_id, "player_1", action)
      assert result == :ok

      # State was updated
      new_state = GameRoom.get_state(room_id)
      assert {:ok, _decoded} = Jason.decode(new_state)
    end

    test "valid move broadcasts state_resolved", %{game: game} do
      {room_id, _pid} = start_room(game)
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

    test "invalid action returns error without mutating state", %{game: game} do
      {room_id, _pid} = start_room(game)
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

  describe "ended game" do
    test "rejects moves when ended: true and returns game_over error", %{game: game} do
      {room_id, pid} = start_room(game)

      # Force the room into the ended state directly
      :sys.replace_state(pid, fn state -> %{state | ended: true} end)

      result = GameRoom.make_move(room_id, "player_1", ~s("EndTurn"))
      assert {:error, %{type: "game_over", message: "Game has ended"}} = result
    end
  end

  describe "make_move/3 with repeated calls" do
    test "handles multiple sequential moves without crashing", %{game: game} do
      {room_id, _pid} = start_room(game)

      action = ~s("EndTurn")

      assert GameRoom.make_move(room_id, "player_1", action) == :ok
      assert GameRoom.make_move(room_id, "player_1", action) == :ok
    end
  end

  describe "turn boundary handling" do
    test "EndTurn action does not crash", %{game: game} do
      {room_id, _pid} = start_room(game)
      action = ~s("EndTurn")

      # Should not raise
      result = GameRoom.make_move(room_id, "player_1", action)
      assert result == :ok
    end

    test "EndTurn increments turn_number in GenServer state", %{game: game} do
      {room_id, pid} = start_room(game)

      assert GameRoom.make_move(room_id, "player_1", ~s("EndTurn")) == :ok

      %{turn_number: turn} = :sys.get_state(pid)
      assert turn == 1
    end

    test "EndTurn upserts a game_sessions row", %{game: game} do
      {room_id, _pid} = start_room(game)

      assert GameRoom.make_move(room_id, "player_1", ~s("EndTurn")) == :ok

      session = wait_for(fn -> Carddo.Multiplayer.GameSessions.get(room_id) end)
      assert session != nil
      assert session.turn_number == 1
    end
  end
end
