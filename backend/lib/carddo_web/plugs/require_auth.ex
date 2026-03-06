defmodule CarddoWeb.Plugs.RequireAuth do
  import Plug.Conn
  alias Carddo.Accounts.Guardian

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- Guardian.decode_and_verify(token),
         {:ok, user} <- Guardian.resource_from_claims(claims) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> put_status(401)
        |> Phoenix.Controller.json(%{errors: [%{message: "Unauthorized", code: "unauthorized"}]})
        |> halt()
    end
  end
end
