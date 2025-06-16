defmodule CarddoWeb.GameSessionLive.Components.PlayerAreaComponent do
  use CarddoWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class={["player-area", @is_current_player && "current-player"]}>
      <div class="player-info flex items-center justify-between mb-4">
        <div class="player-stats">
          <span class="text-pearl">Life: <%= @player.life_points %></span>
          <span class="text-cool_gray ml-4">Mana: <%= @player.mana %></span>
        </div>
        <div class="deck-info">
          <span class="text-pearl">Deck: <%= length(@player.deck) %></span>
          <span class="text-cool_gray ml-4">Discard: <%= length(@player.discard_pile) %></span>
        </div>
      </div>

      <!-- Play Area -->
      <div class="play-area mb-4">
        <h3 class="text-pearl mb-2">Play Area</h3>
        <div class="grid grid-cols-6 gap-2">
          <.live_component
            :for={card <- @player.play_area}
            module={CarddoWeb.GameSessionLive.Components.CardComponent}
            id={"play-area-card-#{card.id}"}
            card={card}
            zone="play_area"
            interactive={@is_current_player}
          />
        </div>
      </div>

      <!-- Hand (only show for current player) -->
      <div :if={@is_current_player} class="hand">
        <h3 class="text-pearl mb-2">Hand</h3>
        <div class="flex gap-2 overflow-x-auto">
          <.live_component
            :for={card <- @player.hand}
            module={CarddoWeb.GameSessionLive.Components.CardComponent}
            id={"hand-card-#{card.id}"}
            card={card}
            zone="hand"
            interactive={true}
          />
        </div>
      </div>

      <!-- Opponent hand (just card backs) -->
      <div :if={not @is_current_player} class="opponent-hand">
        <div class="flex gap-1">
          <div
            :for={_ <- 1..length(@player.hand)}
            class="w-12 h-16 bg-jet rounded border border-cool_gray"
          />
        </div>
      </div>
    </div>
    """
  end
end
