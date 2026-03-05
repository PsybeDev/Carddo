defmodule Carddo.DeckCardTest do
  use Carddo.DataCase, async: true

  alias Carddo.{Card, Deck, DeckCard, Game, Repo, User}

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

    {:ok, card} =
      Ecto.build_assoc(game, :cards)
      |> Card.changeset(%{name: "Dragon", card_type: "creature"})
      |> Repo.insert()

    %{deck: deck, card: card}
  end

  describe "changeset/2" do
    test "valid with required fields", %{deck: deck, card: card} do
      changeset = DeckCard.changeset(%DeckCard{}, %{deck_id: deck.id, card_id: card.id})
      assert changeset.valid?
    end

    test "valid with explicit quantity", %{deck: deck, card: card} do
      changeset =
        DeckCard.changeset(%DeckCard{}, %{deck_id: deck.id, card_id: card.id, quantity: 3})

      assert changeset.valid?
    end

    test "invalid without deck_id", %{card: card} do
      changeset = DeckCard.changeset(%DeckCard{}, %{card_id: card.id})
      refute changeset.valid?
      assert {:deck_id, {"can't be blank", _}} = List.keyfind(changeset.errors, :deck_id, 0)
    end

    test "invalid without card_id", %{deck: deck} do
      changeset = DeckCard.changeset(%DeckCard{}, %{deck_id: deck.id})
      refute changeset.valid?
      assert {:card_id, {"can't be blank", _}} = List.keyfind(changeset.errors, :card_id, 0)
    end

    test "invalid with quantity nil", %{deck: deck, card: card} do
      changeset =
        DeckCard.changeset(%DeckCard{}, %{deck_id: deck.id, card_id: card.id, quantity: nil})

      refute changeset.valid?
      assert {:quantity, {"can't be blank", _}} = List.keyfind(changeset.errors, :quantity, 0)
    end

    test "invalid with quantity zero", %{deck: deck, card: card} do
      changeset =
        DeckCard.changeset(%DeckCard{}, %{deck_id: deck.id, card_id: card.id, quantity: 0})

      refute changeset.valid?
      assert {:quantity, _} = List.keyfind(changeset.errors, :quantity, 0)
    end
  end

  test "inserts and retrieves a deck_card row", %{deck: deck, card: card} do
    {:ok, dc} =
      DeckCard.changeset(%DeckCard{}, %{deck_id: deck.id, card_id: card.id, quantity: 2})
      |> Repo.insert()

    assert dc.deck_id == deck.id
    assert dc.card_id == card.id
    assert dc.quantity == 2
  end

  test "enforces uniqueness of (deck_id, card_id)", %{deck: deck, card: card} do
    attrs = %{deck_id: deck.id, card_id: card.id}
    DeckCard.changeset(%DeckCard{}, attrs) |> Repo.insert!()

    assert {:error, _} = DeckCard.changeset(%DeckCard{}, attrs) |> Repo.insert()
  end
end
