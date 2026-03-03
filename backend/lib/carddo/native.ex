defmodule Carddo.Native do
  use Rustler,
    otp_app: :carddo,
    crate: :ditto_nif

  
  def process_move(_state_json, _action_json, _player_id), do: :erlang.nif_error(:nif_not_loaded)
end
