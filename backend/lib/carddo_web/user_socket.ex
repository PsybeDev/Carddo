defmodule CarddoWeb.UserSocket do
  use Phoenix.Socket

  channel("room:*", CarddoWeb.GameChannel)

  def connect(%{"token" => token}, socket, _connect_info) do
    case Carddo.Accounts.Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        try do
          user = Carddo.Accounts.get_user!(claims["sub"])
          {:ok, assign(socket, :current_user, user)}
        rescue
          Ecto.NoResultsError -> :error
        end

      _ ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  def id(socket), do: "users_socket:#{socket.assigns.current_user.id}"
end
