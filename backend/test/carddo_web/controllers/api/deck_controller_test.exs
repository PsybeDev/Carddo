defmodule CarddoWeb.Api.DeckControllerTest do
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

  defp create_deck(game, attrs \\ %{}) do
    {:ok, deck} = Games.create_deck(game, Map.merge(%{name: "My Deck"}, attrs))
    deck
  end

  describe "GET /api/games/:game_id/decks" do
    test "returns all decks for the game", %{conn: conn} do
      %{conn: conn, game: game} = setup_game(conn)
      _deck = create_deck(game)
      conn = get(conn, "/api/games/#{game.id}/decks")
      assert %{"data" => decks} = json_response(conn, 200)
      assert length(decks) == 1
      assert hd(decks)["name"] == "My Deck"
    end

    test "returns 403 for another user's game", %{conn: conn} do
      %{conn: conn} = register_and_login(conn)
      %{game: other_game} = setup_game(build_conn())

      conn = get(conn, "/api/games/#{other_game.id}/decks")
      assert json_response(conn, 403)
    end
  end

  describe "POST /api/games/:game_id/decks" do
    test "creates a deck and returns 201", %{conn: conn} do
      %{conn: conn, game: game} = setup_game(conn)
      conn = post(conn, "/api/games/#{game.id}/decks", %{name: "Starter Deck"})
      assert %{"data" => deck} = json_response(conn, 201)
      assert deck["name"] == "Starter Deck"
      assert deck["game_id"] == game.id
    end

    test "returns 422 when name is missing", %{conn: conn} do
      %{conn: conn, game: game} = setup_game(conn)
      conn = post(conn, "/api/games/#{game.id}/decks", %{})
      assert %{"errors" => [%{"message" => msg}]} = json_response(conn, 422)
      assert msg =~ "name"
    end

    test "returns 403 for another user's game", %{conn: conn} do
      %{conn: conn} = register_and_login(conn)
      %{game: other_game} = setup_game(build_conn())

      conn = post(conn, "/api/games/#{other_game.id}/decks", %{name: "X"})
      assert json_response(conn, 403)
    end
  end

  describe "GET /api/games/:game_id/decks/:id" do
    test "returns deck with preloaded card entries", %{conn: conn} do
      %{conn: conn, game: game} = setup_game(conn)
      deck = create_deck(game)
      card = create_card(game)
      Games.set_deck_cards(deck.id, [%{card_id: card.id, quantity: 3}])

      conn = get(conn, "/api/games/#{game.id}/decks/#{deck.id}")
      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == deck.id
      assert length(data["entries"]) == 1
      entry = hd(data["entries"])
      assert entry["card_id"] == card.id
      assert entry["quantity"] == 3
      assert entry["card"]["name"] == "Dragon"
    end

    test "returns 404 for non-existent deck", %{conn: conn} do
      %{conn: conn, game: game} = setup_game(conn)
      conn = get(conn, "/api/games/#{game.id}/decks/0")
      assert json_response(conn, 404)
    end

    test "returns 403 for another user's game", %{conn: conn} do
      %{conn: conn} = register_and_login(conn)
      %{game: other_game} = setup_game(build_conn())
      other_deck = create_deck(other_game)

      conn = get(conn, "/api/games/#{other_game.id}/decks/#{other_deck.id}")
      assert json_response(conn, 403)
    end
  end

  describe "PATCH /api/games/:game_id/decks/:id" do
    test "updates deck name and returns 200", %{conn: conn} do
      %{conn: conn, game: game} = setup_game(conn)
      deck = create_deck(game)

      conn = patch(conn, "/api/games/#{game.id}/decks/#{deck.id}", %{name: "Renamed"})
      assert %{"data" => data} = json_response(conn, 200)
      assert data["name"] == "Renamed"
    end

    test "replaces deck entries atomically", %{conn: conn} do
      %{conn: conn, game: game} = setup_game(conn)
      deck = create_deck(game)
      card1 = create_card(game, %{name: "Card1"})
      card2 = create_card(game, %{name: "Card2"})

      # Set initial entries
      Games.set_deck_cards(deck.id, [%{card_id: card1.id, quantity: 1}])

      # Replace with new entries
      conn =
        patch(conn, "/api/games/#{game.id}/decks/#{deck.id}", %{
          entries: [%{card_id: card2.id, quantity: 4}]
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert length(data["entries"]) == 1
      assert hd(data["entries"])["card_id"] == card2.id
      assert hd(data["entries"])["quantity"] == 4
    end

    test "clears entries when passed empty list", %{conn: conn} do
      %{conn: conn, game: game} = setup_game(conn)
      deck = create_deck(game)
      card = create_card(game)
      Games.set_deck_cards(deck.id, [%{card_id: card.id, quantity: 2}])

      conn = patch(conn, "/api/games/#{game.id}/decks/#{deck.id}", %{entries: []})
      assert %{"data" => data} = json_response(conn, 200)
      assert data["entries"] == []
    end

    test "returns 404 for non-existent deck", %{conn: conn} do
      %{conn: conn, game: game} = setup_game(conn)
      conn = patch(conn, "/api/games/#{game.id}/decks/0", %{name: "X"})
      assert json_response(conn, 404)
    end

    test "returns 403 for another user's game", %{conn: conn} do
      %{conn: conn} = register_and_login(conn)
      %{game: other_game} = setup_game(build_conn())
      other_deck = create_deck(other_game)

      conn = patch(conn, "/api/games/#{other_game.id}/decks/#{other_deck.id}", %{name: "X"})
      assert json_response(conn, 403)
    end
  end

  describe "DELETE /api/games/:game_id/decks/:id" do
    test "deletes deck and returns 204", %{conn: conn} do
      %{conn: conn, game: game} = setup_game(conn)
      deck = create_deck(game)

      conn = delete(conn, "/api/games/#{game.id}/decks/#{deck.id}")
      assert response(conn, 204)
      assert Repo.get(Carddo.Deck, deck.id) == nil
    end

    test "returns 403 for another user's game", %{conn: conn} do
      %{conn: conn} = register_and_login(conn)
      %{game: other_game} = setup_game(build_conn())
      other_deck = create_deck(other_game)

      conn = delete(conn, "/api/games/#{other_game.id}/decks/#{other_deck.id}")
      assert json_response(conn, 403)
    end
  end
end
