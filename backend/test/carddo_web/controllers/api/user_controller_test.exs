defmodule CarddoWeb.Api.UserControllerTest do
  use CarddoWeb.ConnCase, async: true

  alias Carddo.Accounts
  alias Carddo.Accounts.Guardian

  defp unique_email, do: "user-#{System.unique_integer([:positive])}@example.com"

  defp register_and_login(conn, email \\ nil) do
    email = email || unique_email()
    {:ok, user} = Accounts.register_user(%{email: email, password: "password123"})
    {:ok, token, _} = Guardian.encode_and_sign(user)
    conn = put_req_header(conn, "authorization", "Bearer #{token}")
    %{conn: conn, user: user, token: token}
  end

  describe "POST /api/users/register" do
    test "returns 200 with token and user on success", %{conn: conn} do
      conn = post(conn, "/api/users/register", %{email: unique_email(), password: "password123"})
      assert %{"data" => %{"token" => token, "user" => user}} = json_response(conn, 200)
      assert is_binary(token)
      assert user["email"]
      assert user["id"]
      assert user["subscription_tier"]
      refute Map.has_key?(user, "password_hash")
    end

    test "returns 422 with errors on duplicate email", %{conn: conn} do
      email = unique_email()
      post(conn, "/api/users/register", %{email: email, password: "password123"})
      conn = post(conn, "/api/users/register", %{email: email, password: "password123"})
      assert %{"errors" => [%{"message" => msg}]} = json_response(conn, 422)
      assert msg =~ "already been taken"
    end

    test "returns 422 with errors on short password", %{conn: conn} do
      conn = post(conn, "/api/users/register", %{email: unique_email(), password: "short"})
      assert %{"errors" => [%{"message" => msg}]} = json_response(conn, 422)
      assert msg =~ "password"
    end
  end

  describe "POST /api/users/login" do
    setup do
      email = unique_email()
      {:ok, _user} = Accounts.register_user(%{email: email, password: "password123"})
      %{email: email}
    end

    test "returns 200 with token and user on valid credentials", %{conn: conn, email: email} do
      conn = post(conn, "/api/users/login", %{email: email, password: "password123"})
      assert %{"data" => %{"token" => token, "user" => user}} = json_response(conn, 200)
      assert is_binary(token)
      assert user["email"] == email
    end

    test "returns 401 on wrong password", %{conn: conn, email: email} do
      conn = post(conn, "/api/users/login", %{email: email, password: "wrongpassword"})
      assert %{"errors" => [%{"message" => _}]} = json_response(conn, 401)
    end

    test "returns 401 on unknown email", %{conn: conn} do
      conn = post(conn, "/api/users/login", %{email: "nobody@example.com", password: "password123"})
      assert %{"errors" => [%{"message" => _}]} = json_response(conn, 401)
    end
  end

  describe "GET /api/users/me" do
    test "returns 200 with user when authenticated", %{conn: conn} do
      %{conn: conn, user: user} = register_and_login(conn)
      conn = get(conn, "/api/users/me")
      assert %{"data" => %{"id" => id, "email" => email}} = json_response(conn, 200)
      assert id == user.id
      assert email == user.email
    end

    test "returns 401 with no token", %{conn: conn} do
      conn = get(conn, "/api/users/me")
      assert %{"errors" => [%{"message" => "Unauthorized"}]} = json_response(conn, 401)
    end

    test "returns 401 with invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer notavalidtoken")
        |> get("/api/users/me")

      assert %{"errors" => [%{"message" => "Unauthorized"}]} = json_response(conn, 401)
    end
  end
end
