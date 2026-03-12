defmodule Carddo.Multiplayer.GameSessions do
  require Logger
  import Ecto.Query
  alias Carddo.{Repo, GameSession}

  @doc """
  Inserts or updates a game session checkpoint.

  `state_json_string` is the raw JSON string returned by the NIF. It is decoded
  to a map before storage because the column is JSONB.

  Returns `{:ok, %GameSession{}}` or `{:error, changeset | :invalid_json}`.
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

      # Single-round-trip upsert: ON CONFLICT DO UPDATE only fires when the stored
      # turn_number is strictly older than the incoming one, preventing stale
      # out-of-order writes from rolling back a newer checkpoint. When the condition
      # is false (stale write) Postgres returns no rows, so Ecto yields {:ok, %GameSession{id: nil}}.
      Repo.insert(
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
      )
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
