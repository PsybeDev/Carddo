defmodule CarddoWeb.GameLive.Index do
  use CarddoWeb, :live_view

  alias Carddo.Games
  alias Carddo.Games.Game

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :games, Games.list_games())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Game")
    |> assign(:game, Games.get_game!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Game")
    |> assign(:game, %Game{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Games")
    |> assign(:game, nil)
  end

  @impl true
  def handle_info({CarddoWeb.GameLive.FormComponent, {:saved, game}}, socket) do
    {:noreply, stream_insert(socket, :games, game)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    game = Games.get_game!(id)
    {:ok, _} = Games.delete_game(game)

    {:noreply, stream_delete(socket, :games, game)}
  end

  @impl true
  def handle_event("play", %{"id" => id}, socket) do
    {:ok, session} = Games.create_game_session(%{game_id: id})
    {:ok, _} = Games.add_player_to_session(session, socket.assigns.current_user)
    {:noreply, push_redirect(socket, to: ~p"/game-sessions/#{session.id}")}
  end
end
