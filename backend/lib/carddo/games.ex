defmodule Carddo.Games do
  import Ecto.Query
  alias Carddo.{Card, Deck, DeckCard, Game, Repo}

  # ── Games ──────────────────────────────────────────────────────────────────

  def list_games(user_id) do
    Repo.all(from(g in Game, where: g.owner_id == ^user_id, order_by: [desc: g.inserted_at]))
  end

  def create_game(user, attrs) do
    Ecto.build_assoc(user, :games)
    |> Game.changeset(attrs)
    |> Repo.insert()
  end

  def get_game(id) do
    Repo.get(Game, id)
  end

  def update_game(game, attrs) do
    game
    |> Game.update_changeset(attrs)
    |> Repo.update()
  end

  def delete_game(game) do
    Repo.delete(game)
  end

  # ── Cards ──────────────────────────────────────────────────────────────────

  def list_cards(game_id, nil) do
    Repo.all(from(c in Card, where: c.game_id == ^game_id, order_by: [asc: c.inserted_at]))
  end

  def list_cards(game_id, search) when search != "" do
    Repo.all(
      from(c in Card,
        where: c.game_id == ^game_id,
        where: fragment("?::text ILIKE ?", c.properties, ^"%#{search}%"),
        order_by: [asc: c.inserted_at]
      )
    )
  end

  def list_cards(game_id, _search), do: list_cards(game_id, nil)

  def create_card(game, attrs) do
    Ecto.build_assoc(game, :cards)
    |> Card.changeset(attrs)
    |> Repo.insert()
  end

  def get_card(game_id, id) do
    Repo.get_by(Card, id: id, game_id: game_id)
  end

  def update_card(card, attrs) do
    card
    |> Card.changeset(attrs)
    |> Repo.update()
  end

  def delete_card(card) do
    Repo.delete(card)
  end

  # ── Decks ──────────────────────────────────────────────────────────────────

  def list_decks(game_id) do
    Repo.all(from(d in Deck, where: d.game_id == ^game_id, order_by: [asc: d.inserted_at]))
  end

  def create_deck(game, attrs) do
    Ecto.build_assoc(game, :decks)
    |> Deck.changeset(attrs)
    |> Repo.insert()
  end

  def get_deck(game_id, id) do
    Repo.get_by(Deck, id: id, game_id: game_id)
  end

  def update_deck(deck, attrs) do
    deck
    |> Deck.changeset(attrs)
    |> Repo.update()
  end

  def update_deck_full(deck, params) do
    Repo.transaction(fn ->
      deck =
        case params do
          %{"name" => name} ->
            case update_deck(deck, %{name: name}) do
              {:ok, d} -> d
              {:error, cs} -> Repo.rollback(cs)
            end

          _ ->
            deck
        end

      case params do
        %{"entries" => entries} ->
          parsed =
            entries
            |> Enum.map(&%{card_id: &1["card_id"], quantity: max(&1["quantity"] || 1, 1)})
            |> Enum.group_by(& &1.card_id)
            |> Enum.map(fn {card_id, grouped} ->
              %{
                card_id: card_id,
                quantity: Enum.reduce(grouped, 0, fn e, acc -> e.quantity + acc end)
              }
            end)

          unique_card_ids = parsed |> Enum.map(& &1.card_id) |> Enum.uniq()

          if unique_card_ids != [] do
            valid_count =
              Repo.aggregate(
                from(c in Card,
                  where: c.game_id == ^deck.game_id and c.id in ^unique_card_ids
                ),
                :count
              )

            if valid_count != length(unique_card_ids) do
              Repo.rollback(:invalid_card_ids)
            end
          end

          Repo.delete_all(from(dc in DeckCard, where: dc.deck_id == ^deck.id))
          Repo.insert_all(DeckCard, Enum.map(parsed, &Map.put(&1, :deck_id, deck.id)))

        _ ->
          nil
      end

      deck
    end)
  end

  def delete_deck(deck) do
    Repo.delete(deck)
  end

  def get_deck_with_cards(deck_id) do
    Repo.get!(Deck, deck_id) |> Repo.preload(deck_cards: :card)
  end

  def set_deck_cards(deck_id, entries) do
    Repo.transaction(fn ->
      deck = Repo.get!(Deck, deck_id)

      unique_card_ids = entries |> Enum.map(& &1.card_id) |> Enum.uniq()

      if unique_card_ids != [] do
        valid_count =
          Repo.aggregate(
            from(c in Card,
              where: c.game_id == ^deck.game_id and c.id in ^unique_card_ids
            ),
            :count
          )

        if valid_count != length(unique_card_ids) do
          Repo.rollback(:invalid_card_ids)
        end
      end

      parsed =
        entries
        |> Enum.map(&%{card_id: &1.card_id, quantity: max(&1.quantity || 1, 1)})
        |> Enum.group_by(& &1.card_id)
        |> Enum.map(fn {card_id, grouped} ->
          %{
            card_id: card_id,
            quantity: Enum.reduce(grouped, 0, fn e, acc -> e.quantity + acc end)
          }
        end)

      Repo.delete_all(from(dc in DeckCard, where: dc.deck_id == ^deck_id))
      Repo.insert_all(DeckCard, Enum.map(parsed, &Map.put(&1, :deck_id, deck_id)))
    end)
  end
end
