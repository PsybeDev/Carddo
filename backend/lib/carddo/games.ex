defmodule Carddo.Games do
  import Ecto.Query
  alias Carddo.{Repo, Deck, DeckCard}

  def set_deck_cards(deck_id, entries) do
    Repo.transaction(fn ->
      Repo.delete_all(from dc in DeckCard, where: dc.deck_id == ^deck_id)
      Repo.insert_all(DeckCard, Enum.map(entries, &Map.put(&1, :deck_id, deck_id)))
    end)
  end

  def get_deck_with_cards(deck_id) do
    Repo.get!(Deck, deck_id) |> Repo.preload(deck_cards: :card)
  end
end
