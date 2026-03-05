defmodule Carddo.Accounts.Guardian do
  use Guardian, otp_app: :carddo

  def subject_for_token(%Carddo.User{id: id}, _claims), do: {:ok, to_string(id)}

  def resource_from_claims(%{"sub" => id}) do
    {:ok, Carddo.Accounts.get_user!(id)}
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end
end
