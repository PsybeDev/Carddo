defmodule CarddoWeb.Nav do
  import Phoenix.LiveView
  import Phoenix.Component, only: [assign: 2]

  def on_mount(:default, _params, _session, socket) do
    {:cont, socket |> attach_hook(:active_nav, :handle_params, &set_active_nav/3)}
  end

  defp set_active_nav(_params, _url, socket) do
    active_nav =
      case {socket.view, socket.assigns.live_action} do
        {CarddoWeb.UserSettingsLive, _} ->
          :settings

        {CarddoWeb.GameLive.Index, _} ->
          :games

        {_, _} ->
          nil
      end

    {:cont, assign(socket, active_nav: active_nav)}
  end
end
