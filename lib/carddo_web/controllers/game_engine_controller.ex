defmodule CarddoWeb.GameEngineController do
  use CarddoWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end
end
