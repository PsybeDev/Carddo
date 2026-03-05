defmodule Carddo.Accounts do
  alias Carddo.{Repo, User}

  def register_user(attrs) do
    %User{} |> User.registration_changeset(attrs) |> Repo.insert()
  end

  def authenticate_user(email, password) do
    case Repo.get_by(User, email: email) do
      %User{password_hash: hash} = user when not is_nil(hash) ->
        if Bcrypt.verify_pass(password, hash), do: {:ok, user}, else: {:error, :unauthorized}

      _ ->
        Bcrypt.no_user_verify()
        {:error, :unauthorized}
    end
  end

  def get_user!(id), do: Repo.get!(User, id)
end
