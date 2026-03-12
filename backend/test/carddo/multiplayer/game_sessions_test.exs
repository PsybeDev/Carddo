defmodule Carddo.Multiplayer.GameSessionsTest do
  use Carddo.DataCase, async: true

  alias Carddo.{Game, GameSession, Repo, User}
  alias Carddo.Multiplayer.GameSessions

  @empty_state_json ~s({"entities":{},"zones":{},"event_queue":[],"pending_animations":[],"stack_order":"Fifo","state_checks":[]})

  setup do
    {:ok, user} =
      %User{}
      |> User.changeset(%{email: "sessions-#{System.unique_integer([:positive])}@example.com"})
      |> Repo.insert()

    {:ok, game} =
      Ecto.build_assoc(user, :games)
      |> Game.changeset(%{title: "Test Game"})
      |> Repo.insert()

    %{game: game}
  end

  defp room_id, do: "room_#{System.unique_integer([:positive])}"

  describe "upsert/4" do
    test "creates a new session row", %{game: game} do
      rid = room_id()
      assert {:ok, session} = GameSessions.upsert(rid, game.id, @empty_state_json, 0)
      assert session.room_id == rid
      assert session.game_id == game.id
      assert session.turn_number == 0
      assert is_map(session.state_json)
    end

    test "updates an existing session on conflict", %{game: game} do
      rid = room_id()
      assert {:ok, _} = GameSessions.upsert(rid, game.id, @empty_state_json, 0)
      assert {:ok, updated} = GameSessions.upsert(rid, game.id, @empty_state_json, 3)
      assert updated.turn_number == 3
      assert Repo.aggregate(GameSession, :count) >= 1
      # Only one row for this room_id
      assert Repo.one(from(s in GameSession, where: s.room_id == ^rid, select: count())) == 1
    end

    test "stores state as a map (JSONB)", %{game: game} do
      rid = room_id()
      {:ok, session} = GameSessions.upsert(rid, game.id, @empty_state_json, 0)
      assert session.state_json["entities"] == %{}
      assert session.state_json["zones"] == %{}
    end
  end

  describe "get/1" do
    test "returns session after upsert", %{game: game} do
      rid = room_id()
      {:ok, _} = GameSessions.upsert(rid, game.id, @empty_state_json, 1)
      session = GameSessions.get(rid)
      assert %GameSession{} = session
      assert session.room_id == rid
      assert session.turn_number == 1
    end

    test "returns nil for unknown room_id" do
      assert GameSessions.get("nonexistent_room") == nil
    end
  end

  describe "delete/1" do
    test "removes the session row", %{game: game} do
      rid = room_id()
      {:ok, _} = GameSessions.upsert(rid, game.id, @empty_state_json, 0)
      assert %GameSession{} = GameSessions.get(rid)
      GameSessions.delete(rid)
      assert GameSessions.get(rid) == nil
    end

    test "no-ops on unknown room_id" do
      assert {0, _} = GameSessions.delete("nonexistent_room")
    end
  end

  describe "upsert/4 error handling" do
    test "returns {:error, :invalid_json} for malformed JSON string", %{game: game} do
      rid = room_id()
      assert {:error, :invalid_json} = GameSessions.upsert(rid, game.id, "not json {{{", 0)
    end

    test "returns {:error, :invalid_json} for empty string", %{game: game} do
      rid = room_id()
      assert {:error, :invalid_json} = GameSessions.upsert(rid, game.id, "", 0)
    end
  end

  describe "resume flow" do
    test "state_json can be re-encoded to JSON string for NIF", %{game: game} do
      rid = room_id()
      {:ok, _} = GameSessions.upsert(rid, game.id, @empty_state_json, 0)
      session = GameSessions.get(rid)
      resumed_json = Jason.encode!(session.state_json)
      assert {:ok, _decoded} = Jason.decode(resumed_json)
    end
  end
end
