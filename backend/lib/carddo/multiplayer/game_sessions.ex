defmodule Carddo.Multiplayer.GameSessions do
  require Logger
  import Ecto.Query
  alias Carddo.{Repo, GameSession}

  @doc """
  Inserts or updates a game session checkpoint.

  `state_json_string` is the raw JSON string returned by the NIF. It is decoded
  to a map before storage because the column is JSONB.

  The upsert is monotonic: the conflict update only fires when the incoming
  `turn_number` is strictly greater than the stored one, so out-of-order writes
  from concurrent `Task.start` checkpoint tasks never roll back a newer checkpoint.

  Returns:
  - `{:ok, %GameSession{}}` — row was inserted or updated successfully
  - `{:ok, :stale}` — incoming `turn_number` was not newer than the stored one; write silently skipped
  - `{:error, changeset}` — changeset validation failed
  - `{:error, :invalid_json}` — `state_json_string` could not be decoded
  """
  def upsert(room_id, game_id, state_json_string, turn_number)
      when is_binary(state_json_string) do
    with {:ok, state_map} <- Jason.decode(state_json_string) do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      changeset =
        GameSession.changeset(
          %GameSession{room_id: room_id, game_id: game_id},
          %{state_json: state_map, turn_number: turn_number}
        )

      case Repo.insert(
             changeset,
             on_conflict:
               from(s in GameSession,
                 where: s.room_id == ^room_id and s.turn_number < ^turn_number,
                 update: [
                   set: [
                     game_id: ^game_id,
                     state_json: ^state_map,
                     turn_number: ^turn_number,
                     updated_at: ^now
                   ]
                 ]
               ),
             conflict_target: :room_id,
             returning: true
           ) do
        {:ok, %GameSession{id: nil}} -> {:ok, :stale}
        other -> other
      end
    else
      {:error, %Jason.DecodeError{} = reason} ->
        Logger.error("GameSessions.upsert: invalid JSON for room=#{room_id}: #{inspect(reason)}")
        {:error, :invalid_json}
    end
  end

  @doc """
  Returns `%GameSession{}` for the given room_id, or `nil` if none exists.

  When resuming, use `Jason.encode!(session.state_json)` to convert the stored
  map back to a JSON string for the NIF.
  """
  def get(room_id) do
    Repo.get_by(GameSession, room_id: room_id)
  end

  @doc """
  Hard-deletes the game session for a room. Called on game over or TTL expiry.
  """
  def delete(room_id) do
    Repo.delete_all(from(s in GameSession, where: s.room_id == ^room_id))
  end
end
