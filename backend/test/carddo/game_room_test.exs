defmodule Carddo.GameRoomTest do
  # async: false so the SQL sandbox runs in shared mode, allowing background
  # Task.start processes (spawned by GameRoom.make_move/3 for turn checkpointing)
  # and synchronous DB calls in handle_continue/2 (initial checkpoint) to access
  # the DB connection without OwnershipErrors.
  use Carddo.DataCase, async: false

  alias Carddo.{Game, GameRoom, Repo, User}
  alias Phoenix.PubSub

  @empty_state ~s({"entities":{},"zones":{},"event_queue":[],"pending_animations":[],"stack_order":"Fifo","state_checks":[],"turn_ended":false,"game_over":null})

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
  # Raises with a clear message on timeout so CI failures are easy to diagnose.
  defp wait_for(fun, timeout_ms \\ 1000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    wait_for_loop(fun, deadline, timeout_ms)
  end

  defp wait_for_loop(fun, deadline, timeout_ms) do
    case fun.() do
      nil ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(20)
          wait_for_loop(fun, deadline, timeout_ms)
        else
          raise "wait_for/2 timed out after #{timeout_ms}ms waiting for condition to be met"
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
      solo_mode: false,
      ai_player_id: nil,
      player_order: []
    }

    opts = Map.merge(base_opts, Enum.into(opts, %{}))

    {:ok, pid} = start_supervised(Supervisor.child_spec({GameRoom, opts}, restart: :temporary))
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

      session =
        wait_for(fn ->
          s = Carddo.Multiplayer.GameSessions.get(room_id)
          if s && s.turn_number == 1, do: s, else: nil
        end)

      assert session.turn_number == 1
    end
  end

  describe "upsert failure resilience" do
    test "failed checkpoint does not crash the GameRoom", %{game: game} do
      {room_id, pid} = start_room(game)

      wait_for(fn -> Carddo.Multiplayer.GameSessions.get(room_id) end)

      :sys.replace_state(pid, fn state ->
        %{state | game_id: -999_999}
      end)

      assert GameRoom.make_move(room_id, "player_1", ~s("EndTurn")) == :ok

      Process.sleep(100)
      assert Process.alive?(pid)
      assert is_binary(GameRoom.get_state(room_id))
    end
  end

  # State with an entity whose on_after_end_turn hook fires GameOver.
  # GameOver is engine-internal: clients cannot submit it directly.
  @win_condition_state ~s({"entities":{"gc":{"id":"gc","owner_id":"system","template_id":"gc","properties":{},"abilities":[{"id":"win","name":"Win Condition","trigger":"on_after_end_turn","conditions":[],"actions":[{"GameOver":{"winner":"player_1"}}],"cancels":false}]}},"zones":{"void":{"id":"void","owner_id":null,"visibility":"Public","entities":["gc"]}},"event_queue":[],"pending_animations":[],"stack_order":"Fifo","state_checks":[],"turn_ended":false,"game_over":null})

  describe "game_over handling" do
    test "GameOver action broadcasts game_over event with winner", %{game: game} do
      {room_id, _pid} = start_room(game, %{initial_state_json: @win_condition_state})
      topic = "room:#{room_id}"
      PubSub.subscribe(Carddo.PubSub, topic)

      result = GameRoom.make_move(room_id, "player_1", ~s("EndTurn"))
      assert result == :ok

      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^topic,
        event: "game_over",
        payload: %{winner_id: "player_1", final_state: _}
      }
    end

    test "GameOver action sets ended: true in GenServer state", %{game: game} do
      {room_id, pid} = start_room(game, %{initial_state_json: @win_condition_state})
      result = GameRoom.make_move(room_id, "player_1", ~s("EndTurn"))
      assert result == :ok
      %{ended: ended} = :sys.get_state(pid)
      assert ended == true
    end

    test "move after game_over returns game_over error", %{game: game} do
      {room_id, _pid} = start_room(game, %{initial_state_json: @win_condition_state})
      GameRoom.make_move(room_id, "player_1", ~s("EndTurn"))

      result = GameRoom.make_move(room_id, "player_1", ~s("EndTurn"))
      assert {:error, %{type: "game_over", message: "Game has ended"}} = result
    end

    test "GameOver on a turn boundary checkpoints the final state", %{game: game} do
      # State with an entity whose ability fires GameOver immediately after EndTurn.
      # This ensures turn_ended? and game_over_info are both set in the same process_move call.
      state_with_win_condition =
        ~s({"entities":{"gc":{"id":"gc","owner_id":"system","template_id":"gc","properties":{},"abilities":[{"id":"win","name":"Win Condition","trigger":"on_after_end_turn","conditions":[],"actions":[{"GameOver":{"winner":"player_1"}}],"cancels":false}]}},"zones":{"void":{"id":"void","owner_id":null,"visibility":"Public","entities":["gc"]}},"event_queue":[],"pending_animations":[],"stack_order":"Fifo","state_checks":[],"turn_ended":false,"game_over":null})

      {room_id, _pid} = start_room(game, %{initial_state_json: state_with_win_condition})
      topic = "room:#{room_id}"
      PubSub.subscribe(Carddo.PubSub, topic)

      assert GameRoom.make_move(room_id, "player_1", ~s("EndTurn")) == :ok

      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^topic,
        event: "game_over",
        payload: %{winner_id: "player_1"}
      }

      session =
        wait_for(fn ->
          s = Carddo.Multiplayer.GameSessions.get(room_id)
          if s && s.turn_number == 1, do: s, else: nil
        end)

      assert session.turn_number == 1
    end
  end

  describe "TTL expiry" do
    test "ttl_expired deletes session and stops the room", %{game: game} do
      {room_id, pid} = start_room(game)

      wait_for(fn -> Carddo.Multiplayer.GameSessions.get(room_id) end)

      %{ttl_id: ttl_id} = :sys.get_state(pid)
      ref = Process.monitor(pid)
      send(pid, {:ttl_expired, ttl_id})

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000

      wait_for(fn ->
        if Carddo.Multiplayer.GameSessions.get(room_id) == nil, do: :deleted, else: nil
      end)
    end
  end

  describe "crash recovery" do
    test "checkpointed state survives room restart", %{game: game} do
      {room_id, pid} = start_room(game)

      assert GameRoom.make_move(room_id, "player_1", ~s("EndTurn")) == :ok

      session =
        wait_for(fn ->
          s = Carddo.Multiplayer.GameSessions.get(room_id)
          if s && s.turn_number == 1, do: s, else: nil
        end)

      assert session.turn_number == 1

      ref = Process.monitor(pid)
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 5000

      resumed_state_json = Jason.encode!(session.state_json)

      new_room_id = "resumed_#{System.unique_integer([:positive])}"

      {:ok, new_pid} =
        start_supervised(
          Supervisor.child_spec(
            {GameRoom,
             %{
               room_id: new_room_id,
               game_id: game.id,
               initial_state_json: resumed_state_json,
               solo_mode: false,
               ai_player_id: nil,
               player_order: []
             }},
            restart: :temporary
          ),
          id: :resumed_room
        )

      recovered_state = GameRoom.get_state(new_room_id)
      assert {:ok, decoded} = Jason.decode(recovered_state)

      assert decoded["entities"] == session.state_json["entities"]
      assert decoded["zones"] == session.state_json["zones"]
      assert Process.alive?(new_pid)
    end

    test "mid-turn crash loses only current turn", %{game: game} do
      {room_id, pid} = start_room(game)

      assert GameRoom.make_move(room_id, "player_1", ~s("EndTurn")) == :ok
      assert GameRoom.make_move(room_id, "player_1", ~s("EndTurn")) == :ok

      session =
        wait_for(fn ->
          s = Carddo.Multiplayer.GameSessions.get(room_id)
          if s && s.turn_number == 2, do: s, else: nil
        end)

      assert session.turn_number == 2
      checkpoint_state = session.state_json

      ref = Process.monitor(pid)
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 5000

      post_crash_session = Carddo.Multiplayer.GameSessions.get(room_id)
      assert post_crash_session.turn_number == 2
      assert post_crash_session.state_json == checkpoint_state
    end
  end

  describe "solo mode AI" do
    @short_delay 50

    defp solo_opts(ai_id, human_id, extra \\ %{}) do
      Map.merge(
        %{
          solo_mode: true,
          ai_player_id: ai_id,
          player_order: [human_id, ai_id],
          ai_action_delay_ms: @short_delay
        },
        extra
      )
    end

    test "AI responds with a state_resolved broadcast after human EndTurn", %{game: game} do
      human_id = "human_1"
      ai_id = "ai_1"

      {room_id, _pid} = start_room(game, solo_opts(ai_id, human_id))

      topic = "room:#{room_id}"
      PubSub.subscribe(Carddo.PubSub, topic)

      assert GameRoom.make_move(room_id, human_id, ~s("EndTurn")) == :ok

      # First broadcast: human EndTurn
      assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "state_resolved"}, 500
      # Second broadcast: AI-originated EndTurn scheduled via :ai_take_action
      assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "state_resolved"}, 500

      info = GameRoom.get_room_info(room_id)
      assert info.solo_mode == true
      assert info.ai_player_id == ai_id
      assert info.player_order == [human_id, ai_id]
    end

    test "state_resolved broadcast carries active_player_id", %{game: game} do
      human_id = "human_1"
      ai_id = "ai_1"

      {room_id, _pid} = start_room(game, solo_opts(ai_id, human_id))

      topic = "room:#{room_id}"
      PubSub.subscribe(Carddo.PubSub, topic)

      assert GameRoom.make_move(room_id, human_id, ~s("EndTurn")) == :ok

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "state_resolved",
                       payload: %{active_player_id: ^ai_id}
                     },
                     500

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "state_resolved",
                       payload: %{active_player_id: ^human_id}
                     },
                     500
    end

    test "get_room_info exposes active_player_id", %{game: game} do
      human_id = "human_1"
      ai_id = "ai_1"

      # Use a long delay so the AI doesn't fire before we read.
      {room_id, _pid} =
        start_room(game, solo_opts(ai_id, human_id, %{ai_action_delay_ms: 5_000}))

      info = GameRoom.get_room_info(room_id)
      assert info.active_player_id == human_id
    end

    test "non-solo mode never schedules an AI broadcast", %{game: game} do
      # Short delay so a regression that mistakenly scheduled the AI would fire
      # well within the refute_receive window below — the default 1500ms delay
      # would otherwise mask the bug.
      {room_id, _pid} = start_room(game, %{ai_action_delay_ms: @short_delay})

      topic = "room:#{room_id}"
      PubSub.subscribe(Carddo.PubSub, topic)

      assert GameRoom.make_move(room_id, "player_1", ~s("EndTurn")) == :ok
      assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "state_resolved"}, 500
      refute_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "state_resolved"}, 200
    end

    test "human move during AI turn is rejected with not_active_player", %{game: game} do
      human_id = "human_1"
      ai_id = "ai_1"

      {room_id, _pid} =
        start_room(game, solo_opts(ai_id, human_id, %{ai_action_delay_ms: 5_000}))

      assert GameRoom.make_move(room_id, human_id, ~s("EndTurn")) == :ok

      assert {:error, %{type: "not_active_player"}} =
               GameRoom.make_move(room_id, human_id, ~s("EndTurn"))
    end

    test ":ai_take_action is a no-op when active player is human", %{game: game} do
      human_id = "human_1"
      ai_id = "ai_1"

      {room_id, pid} = start_room(game, solo_opts(ai_id, human_id))

      topic = "room:#{room_id}"
      PubSub.subscribe(Carddo.PubSub, topic)

      send(pid, :ai_take_action)

      refute_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "state_resolved"}, 200
    end

    test "AI action cap forces EndTurn when cap is hit", %{game: game} do
      human_id = "human_1"
      ai_id = "ai_1"

      {room_id, pid} =
        start_room(game, solo_opts(ai_id, human_id, %{ai_max_actions_per_turn: 3}))

      # Simulate the AI already having taken max actions this turn.
      :sys.replace_state(pid, fn s ->
        %{s | active_player_id: ai_id, ai_actions_this_turn: 3}
      end)

      topic = "room:#{room_id}"
      PubSub.subscribe(Carddo.PubSub, topic)

      send(pid, :ai_take_action)

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "state_resolved",
                       payload: %{active_player_id: ^human_id}
                     },
                     500

      %{ai_actions_this_turn: counter, active_player_id: active} = :sys.get_state(pid)
      assert active == human_id
      assert counter == 0
    end

    test "AI valid_actions error triggers fallback recovery path", %{game: game} do
      import ExUnit.CaptureLog

      human_id = "human_1"
      ai_id = "ai_1"

      {room_id, pid} = start_room(game, solo_opts(ai_id, human_id))

      # Corrupt the engine state so valid_actions_for_player returns {:error, _},
      # driving the fallback recovery path in pick_and_apply_ai_action. The
      # recovery's own EndTurn attempt will also fail against the bad state —
      # which is what we want to verify is logged cleanly rather than crashing
      # the room.
      :sys.replace_state(pid, fn s ->
        %{s | active_player_id: ai_id, rust_state_json: "not-valid-json"}
      end)

      topic = "room:#{room_id}"
      PubSub.subscribe(Carddo.PubSub, topic)

      log =
        capture_log(fn ->
          send(pid, :ai_take_action)
          # Give the GenServer time to handle the info message and log.
          Process.sleep(100)
        end)

      assert log =~ "AI valid_actions_for_player failed"
      assert log =~ "forcing EndTurn recovery"
      assert log =~ "AI recovery EndTurn failed"
      refute_received %Phoenix.Socket.Broadcast{topic: ^topic, event: "state_resolved"}
      assert Process.alive?(pid)
    end
  end

  describe "solo mode persistence" do
    test "solo_mode skips initial checkpoint", %{game: game} do
      {room_id, _pid} =
        start_room(game, %{
          solo_mode: true,
          ai_player_id: "ai_1",
          player_order: ["human_1", "ai_1"]
        })

      # Give a brief window for any mistaken background write to show up.
      Process.sleep(100)

      assert Carddo.Multiplayer.GameSessions.get(room_id) == nil
    end

    test "solo_mode skips turn-boundary checkpoint", %{game: game} do
      {room_id, _pid} =
        start_room(game, %{
          solo_mode: true,
          ai_player_id: "ai_1",
          player_order: ["human_1", "ai_1"],
          ai_action_delay_ms: 5_000
        })

      assert GameRoom.make_move(room_id, "human_1", ~s("EndTurn")) == :ok

      # Wait long enough for a potential async checkpoint to land.
      Process.sleep(150)
      assert Carddo.Multiplayer.GameSessions.get(room_id) == nil
    end

    test "solo_mode skips game_over checkpoint", %{game: game} do
      {room_id, _pid} =
        start_room(game, %{
          solo_mode: true,
          ai_player_id: "ai_1",
          player_order: ["human_1", "ai_1"],
          ai_action_delay_ms: 5_000,
          initial_state_json: @win_condition_state
        })

      assert GameRoom.make_move(room_id, "human_1", ~s("EndTurn")) == :ok

      Process.sleep(150)
      assert Carddo.Multiplayer.GameSessions.get(room_id) == nil
    end
  end
end
