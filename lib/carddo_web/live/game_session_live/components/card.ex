defmodule CarddoWeb.GameSessionLive.Components.CardComponent do
  use CarddoWeb, :live_component

  def render(assigns) do
    ~H"""
    <div
      class={[
        "card relative bg-pearl rounded-lg shadow-lg transition-transform duration-200",
        card_size_class(@zone),
        @interactive && "hover:scale-105 cursor-pointer"
      ]}
      phx-click={@interactive && "play_card"}
      phx-value-card-id={@card.id}
      phx-target={@myself}
    >
      <div class="card-header p-2 bg-bittersweet_shimmer text-white rounded-t-lg">
        <div class="flex justify-between items-center">
          <span class="font-bold text-sm"><%= @card.name %></span>
          <span class="cost bg-white text-bittersweet_shimmer rounded-full w-6 h-6 flex items-center justify-center text-xs font-bold">
            <%= @card.cost %>
          </span>
        </div>
      </div>

      <div class="card-image h-20 bg-gray-300 rounded-none">
        <img
          :if={@card.image_url}
          src={@card.image_url}
          alt={@card.name}
          class="w-full h-full object-cover"
        />
      </div>

      <div class="card-text p-2">
        <p class="text-xs text-jet"><%= @card.description %></p>
      </div>

      <div :if={@card.power && @card.toughness} class="card-stats flex justify-between p-2 pt-0">
        <span class="text-xs font-bold text-bittersweet_shimmer">
          <%= @card.power %>/<%= @card.toughness %>
        </span>
      </div>
    </div>
    """
  end

  def handle_event("play_card", %{"card-id" => card_id}, socket) do
    send(self(), {:play_card, card_id})
    {:noreply, socket}
  end

  defp card_size_class("hand"), do: "w-24 h-32"
  defp card_size_class("play_area"), do: "w-20 h-28"
  defp card_size_class(_), do: "w-16 h-24"
end
