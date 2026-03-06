defmodule CarddoWeb.Api.DeckController do
  use CarddoWeb, :controller

  alias Carddo.Games

  def index(conn, %{"game_id" => game_id}) do
    case authorize_game(game_id, conn.assigns.current_user) do
      {:ok, _game} ->
        decks = Games.list_decks(game_id)
        json(conn, %{data: Enum.map(decks, &render_deck/1)})

      {:error, :not_found} ->
        not_found(conn)

      {:error, :forbidden} ->
        forbidden(conn)
    end
  end

  def create(conn, %{"game_id" => game_id} = params) do
    case authorize_game(game_id, conn.assigns.current_user) do
      {:ok, game} ->
        case Games.create_deck(game, params) do
          {:ok, deck} ->
            conn
            |> put_status(201)
            |> json(%{data: render_deck(deck)})

          {:error, changeset} ->
            conn
            |> put_status(422)
            |> json(%{errors: format_errors(changeset)})
        end

      {:error, :not_found} ->
        not_found(conn)

      {:error, :forbidden} ->
        forbidden(conn)
    end
  end

  def show(conn, %{"game_id" => game_id, "id" => id}) do
    case authorize_game(game_id, conn.assigns.current_user) do
      {:ok, _game} ->
        case Games.get_deck(game_id, id) do
          nil ->
            not_found(conn)

          deck ->
            deck_with_cards = Games.get_deck_with_cards(deck.id)
            json(conn, %{data: render_deck_with_cards(deck_with_cards)})
        end

      {:error, :not_found} ->
        not_found(conn)

      {:error, :forbidden} ->
        forbidden(conn)
    end
  end

  def update(conn, %{"game_id" => game_id, "id" => id} = params) do
    case authorize_game(game_id, conn.assigns.current_user) do
      {:ok, _game} ->
        case Games.get_deck(game_id, id) do
          nil ->
            not_found(conn)

          deck ->
            case Games.update_deck_full(deck, params) do
              {:ok, updated_deck} ->
                deck_with_cards = Games.get_deck_with_cards(updated_deck.id)
                json(conn, %{data: render_deck_with_cards(deck_with_cards)})

              {:error, :invalid_card_ids} ->
                conn
                |> put_status(422)
                |> json(%{
                  errors: [
                    %{
                      message: "one or more card_ids are invalid or belong to a different game",
                      code: "invalid_card_ids"
                    }
                  ]
                })

              {:error, %Ecto.Changeset{} = changeset} ->
                conn
                |> put_status(422)
                |> json(%{errors: format_errors(changeset)})
            end
        end

      {:error, :not_found} ->
        not_found(conn)

      {:error, :forbidden} ->
        forbidden(conn)
    end
  end

  def delete(conn, %{"game_id" => game_id, "id" => id}) do
    case authorize_game(game_id, conn.assigns.current_user) do
      {:ok, _game} ->
        case Games.get_deck(game_id, id) do
          nil ->
            not_found(conn)

          deck ->
            case Games.delete_deck(deck) do
              {:ok, _} ->
                send_resp(conn, 204, "")

              {:error, changeset} ->
                conn
                |> put_status(422)
                |> json(%{errors: format_errors(changeset)})
            end
        end

      {:error, :not_found} ->
        not_found(conn)

      {:error, :forbidden} ->
        forbidden(conn)
    end
  end

  defp authorize_game(game_id, current_user) do
    case Games.get_game(game_id) do
      nil -> {:error, :not_found}
      game -> if game.owner_id == current_user.id, do: {:ok, game}, else: {:error, :forbidden}
    end
  end

  defp render_deck(deck) do
    %{
      id: deck.id,
      game_id: deck.game_id,
      name: deck.name,
      inserted_at: deck.inserted_at,
      updated_at: deck.updated_at
    }
  end

  defp render_deck_with_cards(deck) do
    Map.merge(render_deck(deck), %{
      entries:
        Enum.map(deck.deck_cards, fn dc ->
          %{
            card_id: dc.card_id,
            quantity: dc.quantity,
            card: %{
              id: dc.card.id,
              name: dc.card.name,
              card_type: dc.card.card_type,
              background_color: dc.card.background_color,
              properties: dc.card.properties,
              abilities: dc.card.abilities
            }
          }
        end)
    })
  end

  defp not_found(conn) do
    conn
    |> put_status(404)
    |> json(%{errors: [%{message: "Not found", code: "not_found"}]})
  end

  defp forbidden(conn) do
    conn
    |> put_status(403)
    |> json(%{errors: [%{message: "Forbidden", code: "forbidden"}]})
  end

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.flat_map(fn {field, messages} ->
      Enum.map(messages, fn msg -> %{message: "#{field} #{msg}", code: "validation_error"} end)
    end)
  end
end
