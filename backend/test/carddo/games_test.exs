defmodule Carddo.GamesTest do
  use Carddo.DataCase, async: true

  alias Carddo.{Card, Deck, Game, Games, Repo, User}

  setup do
    {:ok, user} =
      %User{}
      |> User.changeset(%{email: "test-#{System.unique_integer([:positive])}@example.com"})
      |> Repo.insert()

    {:ok, game} =
      Ecto.build_assoc(user, :games)
      |> Game.changeset(%{title: "Test Game"})
      |> Repo.insert()

    {:ok, deck} =
      Ecto.build_assoc(game, :decks)
      |> Deck.changeset(%{name: "Test Deck"})
      |> Repo.insert()

    {:ok, card1} =
      Ecto.build_assoc(game, :cards)
      |> Card.changeset(%{name: "Dragon", card_type: "creature"})
      |> Repo.insert()

    {:ok, card2} =
      Ecto.build_assoc(game, :cards)
      |> Card.changeset(%{name: "Goblin", card_type: "creature"})
      |> Repo.insert()

    %{deck: deck, card1: card1, card2: card2}
  end

  describe "set_deck_cards/2" do
    test "inserts entries for the deck", %{deck: deck, card1: card1} do
      assert {:ok, _} = Games.set_deck_cards(deck.id, [%{card_id: card1.id, quantity: 2}])

      result = Games.get_deck_with_cards(deck.id)
      assert length(result.deck_cards) == 1
      assert hd(result.deck_cards).card_id == card1.id
      assert hd(result.deck_cards).quantity == 2
    end

    test "replaces existing entries atomically", %{deck: deck, card1: card1, card2: card2} do
      Games.set_deck_cards(deck.id, [%{card_id: card1.id, quantity: 1}])
      Games.set_deck_cards(deck.id, [%{card_id: card2.id, quantity: 3}])

      result = Games.get_deck_with_cards(deck.id)
      assert length(result.deck_cards) == 1
      assert hd(result.deck_cards).card_id == card2.id
      assert hd(result.deck_cards).quantity == 3
    end

    test "clears deck when called with empty list", %{deck: deck, card1: card1} do
      Games.set_deck_cards(deck.id, [%{card_id: card1.id, quantity: 1}])
      assert {:ok, _} = Games.set_deck_cards(deck.id, [])

      result = Games.get_deck_with_cards(deck.id)
      assert result.deck_cards == []
    end

    test "supports multiple cards", %{deck: deck, card1: card1, card2: card2} do
      entries = [%{card_id: card1.id, quantity: 2}, %{card_id: card2.id, quantity: 4}]
      assert {:ok, _} = Games.set_deck_cards(deck.id, entries)

      result = Games.get_deck_with_cards(deck.id)
      assert length(result.deck_cards) == 2
    end
  end

  describe "get_deck_with_cards/1" do
    test "returns deck with preloaded deck_cards and card", %{deck: deck, card1: card1} do
      Games.set_deck_cards(deck.id, [%{card_id: card1.id, quantity: 1}])

      result = Games.get_deck_with_cards(deck.id)
      assert result.id == deck.id
      assert length(result.deck_cards) == 1
      assert hd(result.deck_cards).card.name == "Dragon"
    end

    test "raises when deck not found" do
      assert_raise Ecto.NoResultsError, fn -> Games.get_deck_with_cards(-1) end
    end
  end
end
