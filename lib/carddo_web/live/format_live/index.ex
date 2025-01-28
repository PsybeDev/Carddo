defmodule CarddoWeb.FormatLive.Index do
  use CarddoWeb, :live_view

  alias Carddo.Formats
  alias Carddo.Formats.Format

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :formats, Formats.list_formats())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Format")
    |> assign(:format, Formats.get_format!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Format")
    |> assign(:format, %Format{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Formats")
    |> assign(:format, nil)
  end

  @impl true
  def handle_info({CarddoWeb.FormatLive.FormComponent, {:saved, format}}, socket) do
    {:noreply, stream_insert(socket, :formats, format)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    format = Formats.get_format!(id)
    {:ok, _} = Formats.delete_format(format)

    {:noreply, stream_delete(socket, :formats, format)}
  end
end
