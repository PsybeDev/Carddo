defmodule Carddo.Native do
  use Rustler,
    otp_app: :carddo,
    crate: :ditto_nif,
    path: "../ditto_engine/ditto_nif",
    mode: if(Mix.env() == :prod, do: :release, else: :debug)

  def process_move(_state_json, _action_json, _player_id), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns every currently-legal `Action` that `player_id` could submit, as a
  JSON-encoded array string. Used by `Carddo.GameRoom` to drive the solo-mode
  AI (CAR-46).

  Shapes:
    `{:ok, actions_json}` on success
    `{:error, reason}` on deserialisation or serialisation failure
  """
  def valid_actions_for_player(_state_json, _player_id), do: :erlang.nif_error(:nif_not_loaded)
end
