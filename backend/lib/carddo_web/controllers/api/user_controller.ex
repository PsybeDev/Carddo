defmodule CarddoWeb.Api.UserController do
  use CarddoWeb, :controller

  alias Carddo.Accounts
  alias Carddo.Accounts.Guardian

  def register(conn, %{"email" => email, "password" => password}) do
    case Accounts.register_user(%{email: email, password: password}) do
      {:ok, user} ->
        {:ok, token, _claims} = Guardian.encode_and_sign(user)
        json(conn, %{data: %{token: token, user: render_user(user)}})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        {:ok, token, _claims} = Guardian.encode_and_sign(user)
        json(conn, %{data: %{token: token, user: render_user(user)}})

      {:error, :unauthorized} ->
        conn
        |> put_status(401)
        |> json(%{errors: [%{message: "Invalid email or password"}]})
    end
  end

  def me(conn, _params) do
    json(conn, %{data: render_user(conn.assigns.current_user)})
  end

  defp render_user(user) do
    %{id: user.id, email: user.email, subscription_tier: user.subscription_tier}
  end

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.flat_map(fn {field, messages} ->
      Enum.map(messages, fn msg -> %{message: "#{field} #{msg}"} end)
    end)
  end
end
