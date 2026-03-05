defmodule Carddo.Accounts do
  alias Carddo.{Repo, User}

  def register_user(attrs) do
    %User{} |> User.registration_changeset(attrs) |> Repo.insert()
  end

  def authenticate_user(email, password) do
    user = Repo.get_by(User, email: email)

    if user && Bcrypt.verify_pass(password, user.password_hash) do
      {:ok, user}
    else
      Bcrypt.no_user_verify()
      {:error, :unauthorized}
    end
  end

  def get_user!(id), do: Repo.get!(User, id)
end
