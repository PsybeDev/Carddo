defmodule CarddoWeb.FormatLive.Show do
  use CarddoWeb, :live_view

  alias Carddo.Formats

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:format, Formats.get_format!(id))}
  end

  defp page_title(:show), do: "Show Format"
  defp page_title(:edit), do: "Edit Format"
end
