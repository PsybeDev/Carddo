defmodule Carddo.GameRegistry do
  def via_tuple(room_id), do: {:via, Registry, {__MODULE__, room_id}}
  def lookup(room_id), do: Registry.lookup(__MODULE__, room_id)
end
