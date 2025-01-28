defmodule CarddoWeb.FormatLive.FormComponent do
  use CarddoWeb, :live_component

  alias Carddo.Formats

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage format records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="format-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:description]} type="text" label="Description" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Format</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{format: format} = assigns, socket) do
    changeset = Formats.change_format(format)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"format" => format_params}, socket) do
    changeset =
      socket.assigns.format
      |> Formats.change_format(format_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"format" => format_params}, socket) do
    save_format(socket, socket.assigns.action, format_params)
  end

  defp save_format(socket, :edit, format_params) do
    case Formats.update_format(socket.assigns.format, format_params) do
      {:ok, format} ->
        notify_parent({:saved, format})

        {:noreply,
         socket
         |> put_flash(:info, "Format updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_format(socket, :new, format_params) do
    case Formats.create_format(format_params) do
      {:ok, format} ->
        notify_parent({:saved, format})

        {:noreply,
         socket
         |> put_flash(:info, "Format created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
