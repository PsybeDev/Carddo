defmodule Carddo.MultiplayerTest do
  # async: false required so spawned GameRoom processes share the DB sandbox
  use Carddo.DataCase, async: false

  alias Carddo.{Game, Multiplayer, Repo, User}

  @empty_state ~s({"entities":{},"zones":{},"event_queue":[],"pending_animations":[],"stack_order":"Fifo","state_checks":[]})

  setup do
    {:ok, user} =
      %User{}
      |> User.changeset(%{email: "multiplayer-#{System.unique_integer([:positive])}@example.com"})
      |> Repo.insert()

    {:ok, game} =
      Ecto.build_assoc(user, :games)
      |> Game.changeset(%{title: "Test Game"})
      |> Repo.insert()

    %{game_id: game.id}
  end

  defp unique_room_id, do: "multiplayer_test_#{System.unique_integer([:positive])}"

  defp room_opts(room_id, game_id, extra \\ %{}) do
    Map.merge(
      %{
        room_id: room_id,
        game_id: game_id,
        initial_state_json: @empty_state
      },
      extra
    )
  end

  defp cleanup(pid) do
    DynamicSupervisor.terminate_child(Carddo.Multiplayer.RoomSupervisor, pid)
  end

  # With the improved room_exists?/1 checking Process.alive?, this should now
  # return false immediately after the process dies, even before Registry cleanup.
  defp wait_until_gone(room_id) do
    !Multiplayer.room_exists?(room_id)
  end

  describe "start_room/1" do
    test "returns {:ok, pid} and registers the room", %{game_id: game_id} do
      room_id = unique_room_id()

      assert {:ok, pid} = Multiplayer.start_room(room_opts(room_id, game_id))
      on_exit(fn -> cleanup(pid) end)

      assert is_pid(pid)
      assert Multiplayer.room_exists?(room_id)
    end

    test "returns error when room with same id already exists", %{game_id: game_id} do
      room_id = unique_room_id()

      assert {:ok, pid} = Multiplayer.start_room(room_opts(room_id, game_id))
      on_exit(fn -> cleanup(pid) end)

      assert {:error, {:already_started, _pid}} =
               Multiplayer.start_room(room_opts(room_id, game_id))
    end

    test "solo_mode defaults to false", %{game_id: game_id} do
      room_id = unique_room_id()

      assert {:ok, pid} = Multiplayer.start_room(room_opts(room_id, game_id))
      on_exit(fn -> cleanup(pid) end)

      assert :sys.get_state(pid).solo_mode == false
    end
  end

  describe "room_exists?/1" do
    test "returns false for unknown room" do
      refute Multiplayer.room_exists?("nonexistent_#{unique_room_id()}")
    end

    test "returns false after the room process is killed", %{game_id: game_id} do
      room_id = unique_room_id()
      {:ok, pid} = Multiplayer.start_room(room_opts(room_id, game_id))

      ref = Process.monitor(pid)
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}

      assert wait_until_gone(room_id)
    end

    test "killing one room does not affect another", %{game_id: game_id} do
      room_a = unique_room_id()
      room_b = unique_room_id()

      {:ok, pid_a} = Multiplayer.start_room(room_opts(room_a, game_id))
      {:ok, pid_b} = Multiplayer.start_room(room_opts(room_b, game_id))
      on_exit(fn -> cleanup(pid_b) end)

      ref = Process.monitor(pid_a)
      Process.exit(pid_a, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid_a, :killed}

      assert wait_until_gone(room_a)
      assert Multiplayer.room_exists?(room_b)
    end
  end
end
