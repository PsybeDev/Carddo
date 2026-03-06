defmodule CarddoWeb.Api.CardController do
  use CarddoWeb, :controller

  alias Carddo.Games

  def index(conn, %{"game_id" => game_id} = params) do
    case authorize_game(game_id, conn.assigns.current_user) do
      {:ok, _game} ->
        cards = Games.list_cards(game_id, params["search"])
        json(conn, %{data: Enum.map(cards, &render_card/1)})

      {:error, :not_found} ->
        not_found(conn)

      {:error, :forbidden} ->
        forbidden(conn)
    end
  end

  def create(conn, %{"game_id" => game_id} = params) do
    case authorize_game(game_id, conn.assigns.current_user) do
      {:ok, game} ->
        case Games.create_card(game, params) do
          {:ok, card} ->
            conn
            |> put_status(201)
            |> json(%{data: render_card(card)})

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

  def update(conn, %{"game_id" => game_id, "id" => id} = params) do
    case authorize_game(game_id, conn.assigns.current_user) do
      {:ok, game} ->
        with {:ok, card_id} <- parse_id(id),
             card when not is_nil(card) <- Games.get_card(game.id, card_id) do
          case Games.update_card(card, params) do
            {:ok, updated} ->
              json(conn, %{data: render_card(updated)})

            {:error, changeset} ->
              conn
              |> put_status(422)
              |> json(%{errors: format_errors(changeset)})
          end
        else
          _ -> not_found(conn)
        end

      {:error, :not_found} ->
        not_found(conn)

      {:error, :forbidden} ->
        forbidden(conn)
    end
  end

  def delete(conn, %{"game_id" => game_id, "id" => id}) do
    case authorize_game(game_id, conn.assigns.current_user) do
      {:ok, game} ->
        with {:ok, card_id} <- parse_id(id),
             card when not is_nil(card) <- Games.get_card(game.id, card_id) do
          case Games.delete_card(card) do
            {:ok, _} ->
              send_resp(conn, 204, "")

            {:error, changeset} ->
              conn
              |> put_status(422)
              |> json(%{errors: format_errors(changeset)})
          end
        else
          _ -> not_found(conn)
        end

      {:error, :not_found} ->
        not_found(conn)

      {:error, :forbidden} ->
        forbidden(conn)
    end
  end

  defp authorize_game(game_id, current_user) do
    with {:ok, id} <- parse_id(game_id),
         game when not is_nil(game) <- Games.get_game(id) do
      if game.owner_id == current_user.id, do: {:ok, game}, else: {:error, :forbidden}
    else
      _ -> {:error, :not_found}
    end
  end

  defp parse_id(id) do
    case Integer.parse(to_string(id)) do
      {int, ""} -> {:ok, int}
      _ -> :error
    end
  end

  defp render_card(card) do
    %{
      id: card.id,
      game_id: card.game_id,
      name: card.name,
      card_type: card.card_type,
      background_color: card.background_color,
      properties: card.properties,
      abilities: card.abilities,
      inserted_at: card.inserted_at,
      updated_at: card.updated_at
    }
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
