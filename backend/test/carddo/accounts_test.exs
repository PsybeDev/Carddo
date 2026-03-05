defmodule Carddo.AccountsTest do
  use Carddo.DataCase, async: true

  alias Carddo.Accounts

  defp unique_email, do: "user-#{System.unique_integer([:positive])}@example.com"

  describe "register_user/1" do
    test "succeeds with valid attrs" do
      assert {:ok, user} = Accounts.register_user(%{email: unique_email(), password: "password123"})
      assert user.id
      assert user.password_hash
      refute user.password_hash == "password123"
    end

    test "returns error on duplicate email" do
      email = unique_email()
      assert {:ok, _} = Accounts.register_user(%{email: email, password: "password123"})
      assert {:error, changeset} = Accounts.register_user(%{email: email, password: "password123"})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "returns error when password is too short" do
      assert {:error, changeset} = Accounts.register_user(%{email: unique_email(), password: "short"})
      assert "should be at least 8 character(s)" in errors_on(changeset).password
    end

    test "returns error when email is missing" do
      assert {:error, changeset} = Accounts.register_user(%{password: "password123"})
      assert "can't be blank" in errors_on(changeset).email
    end

    test "returns error when password is missing" do
      assert {:error, changeset} = Accounts.register_user(%{email: unique_email()})
      assert "can't be blank" in errors_on(changeset).password
    end
  end

  describe "authenticate_user/2" do
    setup do
      email = unique_email()
      {:ok, user} = Accounts.register_user(%{email: email, password: "password123"})
      %{user: user, email: email}
    end

    test "succeeds with correct credentials", %{user: user, email: email} do
      assert {:ok, authenticated} = Accounts.authenticate_user(email, "password123")
      assert authenticated.id == user.id
    end

    test "returns :unauthorized for wrong password", %{email: email} do
      assert {:error, :unauthorized} = Accounts.authenticate_user(email, "wrongpassword")
    end

    test "returns :unauthorized for unknown email" do
      assert {:error, :unauthorized} = Accounts.authenticate_user("nobody@example.com", "password123")
    end
  end
end
