defmodule CarddoWeb.Api.GameControllerTest do
  use CarddoWeb.ConnCase, async: true

  alias Carddo.{Accounts, Games, Repo}
  alias Carddo.Accounts.Guardian

  defp unique_email, do: "user-#{System.unique_integer([:positive])}@example.com"

  defp register_and_login(conn, email \\ nil) do
    email = email || unique_email()
    {:ok, user} = Accounts.register_user(%{email: email, password: "password123"})
    {:ok, token, _} = Guardian.encode_and_sign(user)
    conn = put_req_header(conn, "authorization", "Bearer #{token}")
    %{conn: conn, user: user, token: token}
  end

  defp create_game_for(user, attrs \\ %{}) do
    {:ok, game} = Games.create_game(user, Map.merge(%{title: "My Game"}, attrs))
    game
  end

  describe "GET /api/games" do
    test "returns empty list when user has no games", %{conn: conn} do
      %{conn: conn} = register_and_login(conn)
      conn = get(conn, "/api/games")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns only the current user's games", %{conn: conn} do
      %{conn: conn, user: user} = register_and_login(conn)
      _game = create_game_for(user, %{title: "My Game"})

      %{user: other_user} = register_and_login(build_conn())
      _other_game = create_game_for(other_user, %{title: "Other Game"})

      conn = get(conn, "/api/games")
      assert %{"data" => games} = json_response(conn, 200)
      assert length(games) == 1
      assert hd(games)["title"] == "My Game"
    end

    test "returns 401 without auth", %{conn: conn} do
      conn = get(conn, "/api/games")
      assert json_response(conn, 401)
    end
  end

  describe "POST /api/games" do
    test "creates a game and returns 201", %{conn: conn} do
      %{conn: conn} = register_and_login(conn)
      conn = post(conn, "/api/games", %{title: "New Game"})
      assert %{"data" => game} = json_response(conn, 201)
      assert game["title"] == "New Game"
      assert game["id"]
      assert game["config"] == %{}
    end

    test "returns 422 when title is missing", %{conn: conn} do
      %{conn: conn} = register_and_login(conn)
      conn = post(conn, "/api/games", %{})
      assert %{"errors" => [%{"message" => msg}]} = json_response(conn, 422)
      assert msg =~ "title"
    end
  end

  describe "GET /api/games/:id" do
    test "returns the game with config", %{conn: conn} do
      %{conn: conn, user: user} = register_and_login(conn)
      game = create_game_for(user)
      conn = get(conn, "/api/games/#{game.id}")
      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == game.id
      assert data["title"] == game.title
      assert Map.has_key?(data, "config")
    end

    test "returns 404 for non-existent game", %{conn: conn} do
      %{conn: conn} = register_and_login(conn)
      conn = get(conn, "/api/games/0")
      assert %{"errors" => [%{"code" => "not_found"}]} = json_response(conn, 404)
    end

    test "returns 403 when game belongs to another user", %{conn: conn} do
      %{conn: conn} = register_and_login(conn)
      %{user: other_user} = register_and_login(build_conn())
      other_game = create_game_for(other_user)

      conn = get(conn, "/api/games/#{other_game.id}")
      assert %{"errors" => [%{"code" => "forbidden"}]} = json_response(conn, 403)
    end
  end

  describe "PATCH /api/games/:id" do
    test "updates title and returns 200", %{conn: conn} do
      %{conn: conn, user: user} = register_and_login(conn)
      game = create_game_for(user)
      conn = patch(conn, "/api/games/#{game.id}", %{title: "Updated"})
      assert %{"data" => data} = json_response(conn, 200)
      assert data["title"] == "Updated"
    end

    test "updates config JSONB", %{conn: conn} do
      %{conn: conn, user: user} = register_and_login(conn)
      game = create_game_for(user)
      conn = patch(conn, "/api/games/#{game.id}", %{config: %{max_hand_size: 7}})
      assert %{"data" => data} = json_response(conn, 200)
      assert data["config"]["max_hand_size"] == 7
    end

    test "returns 403 for another user's game", %{conn: conn} do
      %{conn: conn} = register_and_login(conn)
      %{user: other_user} = register_and_login(build_conn())
      other_game = create_game_for(other_user)

      conn = patch(conn, "/api/games/#{other_game.id}", %{title: "Hacked"})
      assert json_response(conn, 403)
    end

    test "returns 404 for non-existent game", %{conn: conn} do
      %{conn: conn} = register_and_login(conn)
      conn = patch(conn, "/api/games/0", %{title: "X"})
      assert json_response(conn, 404)
    end
  end

  describe "DELETE /api/games/:id" do
    test "deletes game and returns 204", %{conn: conn} do
      %{conn: conn, user: user} = register_and_login(conn)
      game = create_game_for(user)
      conn = delete(conn, "/api/games/#{game.id}")
      assert response(conn, 204)
      assert Repo.get(Carddo.Game, game.id) == nil
    end

    test "returns 403 for another user's game", %{conn: conn} do
      %{conn: conn} = register_and_login(conn)
      %{user: other_user} = register_and_login(build_conn())
      other_game = create_game_for(other_user)

      conn = delete(conn, "/api/games/#{other_game.id}")
      assert json_response(conn, 403)
    end
  end
end
