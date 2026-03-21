defmodule CarddoWeb.Api.GameController do
  use CarddoWeb, :controller

  alias Carddo.Games

  def index(conn, _params) do
    games = Games.list_games(conn.assigns.current_user.id)
    json(conn, %{data: Enum.map(games, &render_game/1)})
  end

  def create(conn, params) do
    case Games.create_game(conn.assigns.current_user, params) do
      {:ok, game} ->
        conn
        |> put_status(201)
        |> json(%{data: render_game(game)})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def show(conn, %{"id" => id}) do
    case authorize_game(id, conn.assigns.current_user) do
      {:ok, game} -> json(conn, %{data: render_game(game)})
      {:error, :not_found} -> not_found(conn)
      {:error, :forbidden} -> forbidden(conn)
    end
  end

  def update(conn, %{"id" => id} = params) do
    case authorize_game(id, conn.assigns.current_user) do
      {:ok, game} ->
        case Games.update_game(game, params) do
          {:ok, updated} ->
            json(conn, %{data: render_game(updated)})

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

  def delete(conn, %{"id" => id}) do
    case authorize_game(id, conn.assigns.current_user) do
      {:ok, game} ->
        case Games.delete_game(game) do
          {:ok, _} ->
            send_resp(conn, 204, "")

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

  defp render_game(game) do
    %{
      id: game.id,
      title: game.title,
      description: game.description,
      config: game.config,
      card_count: game.card_count,
      inserted_at: game.inserted_at,
      updated_at: game.updated_at
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
