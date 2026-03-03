defmodule Carddo.Native do
  use Rustler,
    otp_app: :carddo,
    crate: :ditto_nif,
    path: "../ditto_engine/ditto_nif",
    mode: (if Mix.env() == :prod, do: :release, else: :debug)

  
  def process_move(_state_json, _action_json, _player_id), do: :erlang.nif_error(:nif_not_loaded)
end
