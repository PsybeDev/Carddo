defmodule CarddoWeb.PageController do
  use CarddoWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    # ensure active_nav is part of assigns.
    conn = assign(conn, :active_nav, conn.assigns[:active_nav] || nil)
    render(conn, :home, layout: false)
  end
end
