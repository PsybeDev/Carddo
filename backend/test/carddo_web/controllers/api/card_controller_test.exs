defmodule CarddoWeb.Api.CardControllerTest do
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

  defp setup_game(conn) do
    %{conn: conn, user: user} = register_and_login(conn)
    {:ok, game} = Games.create_game(user, %{title: "Test Game"})
    %{conn: conn, user: user, game: game}
  end

  defp create_card(game, attrs \\ %{}) do
    {:ok, card} =
      Games.create_card(game, Map.merge(%{name: "Dragon", card_type: "creature"}, attrs))

    card
  end

  describe "GET /api/games/:game_id/cards" do
    test "returns all cards for the game", %{conn: conn} do
      %{conn: conn, game: game} = setup_game(conn)
      _card = create_card(game)
      conn = get(conn, "/api/games/#{game.id}/cards")
      assert %{"data" => cards} = json_response(conn, 200)
      assert length(cards) == 1
      assert hd(cards)["name"] == "Dragon"
    end

    test "returns empty list when no cards", %{conn: conn} do
      %{conn: conn, game: game} = setup_game(conn)
      conn = get(conn, "/api/games/#{game.id}/cards")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "filters by ?search= against name", %{conn: conn} do
      %{conn: conn, game: game} = setup_game(conn)
      _matching = create_card(game, %{name: "Dragon", properties: %{element: "fire"}})
      _non_matching = create_card(game, %{name: "Goblin", properties: %{element: "earth"}})

      conn = get(conn, "/api/games/#{game.id}/cards?search=drag")
      assert %{"data" => cards} = json_response(conn, 200)
      assert length(cards) == 1
      assert hd(cards)["name"] == "Dragon"
    end

    test "returns 403 for another user's game", %{conn: conn} do
      %{conn: conn} = register_and_login(conn)
      %{game: other_game} = setup_game(build_conn())

      conn = get(conn, "/api/games/#{other_game.id}/cards")
      assert json_response(conn, 403)
    end
  end

  describe "GET /api/games/:game_id/cards/:id" do
    test "returns the card", %{conn: conn} do
      %{conn: conn, game: game} = setup_game(conn)
      card = create_card(game, %{background_color: "#aabbcc", properties: %{health: 10}})

      conn = get(conn, "/api/games/#{game.id}/cards/#{card.id}")
      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == card.id
      assert data["name"] == "Dragon"
      assert data["background_color"] == "#aabbcc"
      assert data["properties"]["health"] == 10
    end

    test "returns 404 when card not found", %{conn: conn} do
      %{conn: conn, game: game} = setup_game(conn)
      conn = get(conn, "/api/games/#{game.id}/cards/0")
      assert json_response(conn, 404)
    end

    test "returns 403 for another user's game", %{conn: conn} do
      %{conn: conn} = register_and_login(conn)
      %{game: other_game} = setup_game(build_conn())
      other_card = create_card(other_game)

      conn = get(conn, "/api/games/#{other_game.id}/cards/#{other_card.id}")
      assert json_response(conn, 403)
    end
  end

  describe "POST /api/games/:game_id/cards" do
    test "creates a card with all fields and returns 201", %{conn: conn} do
      %{conn: conn, game: game} = setup_game(conn)

      conn =
        post(conn, "/api/games/#{game.id}/cards", %{
          name: "Fireball",
          card_type: "spell",
          background_color: "#ff4400",
          properties: %{damage: 5},
          abilities: [%{trigger: "on_play", effect: "deal_damage"}]
        })

      assert %{"data" => card} = json_response(conn, 201)
      assert card["name"] == "Fireball"
      assert card["card_type"] == "spell"
      assert card["background_color"] == "#ff4400"
      assert card["properties"]["damage"] == 5
      assert length(card["abilities"]) == 1
    end

    test "returns 422 when name is missing", %{conn: conn} do
      %{conn: conn, game: game} = setup_game(conn)
      conn = post(conn, "/api/games/#{game.id}/cards", %{card_type: "spell"})
      assert %{"errors" => [%{"message" => msg}]} = json_response(conn, 422)
      assert msg =~ "name"
    end

    test "returns 403 for another user's game", %{conn: conn} do
      %{conn: conn} = register_and_login(conn)
      %{game: other_game} = setup_game(build_conn())

      conn =
        post(conn, "/api/games/#{other_game.id}/cards", %{name: "X", card_type: "creature"})

      assert json_response(conn, 403)
    end
  end

  describe "PATCH /api/games/:game_id/cards/:id" do
    test "updates card fields and returns 200", %{conn: conn} do
      %{conn: conn, game: game} = setup_game(conn)
      card = create_card(game)

      conn =
        patch(conn, "/api/games/#{game.id}/cards/#{card.id}", %{
          name: "Fire Dragon",
          background_color: "#red"
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["name"] == "Fire Dragon"
      assert data["background_color"] == "#red"
    end

    test "returns 404 when card not found", %{conn: conn} do
      %{conn: conn, game: game} = setup_game(conn)
      conn = patch(conn, "/api/games/#{game.id}/cards/0", %{name: "X"})
      assert json_response(conn, 404)
    end

    test "returns 403 for another user's game", %{conn: conn} do
      %{conn: conn} = register_and_login(conn)
      %{game: other_game} = setup_game(build_conn())
      other_card = create_card(other_game)

      conn = patch(conn, "/api/games/#{other_game.id}/cards/#{other_card.id}", %{name: "X"})
      assert json_response(conn, 403)
    end
  end

  describe "DELETE /api/games/:game_id/cards/:id" do
    test "deletes card and returns 204", %{conn: conn} do
      %{conn: conn, game: game} = setup_game(conn)
      card = create_card(game)

      conn = delete(conn, "/api/games/#{game.id}/cards/#{card.id}")
      assert response(conn, 204)
      assert Repo.get(Carddo.Card, card.id) == nil
    end

    test "returns 404 when card not found", %{conn: conn} do
      %{conn: conn, game: game} = setup_game(conn)
      conn = delete(conn, "/api/games/#{game.id}/cards/0")
      assert json_response(conn, 404)
    end

    test "returns 403 for another user's game", %{conn: conn} do
      %{conn: conn} = register_and_login(conn)
      %{game: other_game} = setup_game(build_conn())
      other_card = create_card(other_game)

      conn = delete(conn, "/api/games/#{other_game.id}/cards/#{other_card.id}")
      assert json_response(conn, 403)
    end
  end
end
