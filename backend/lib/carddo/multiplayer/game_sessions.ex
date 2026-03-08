defmodule Carddo.Multiplayer.GameSessions do
  import Ecto.Query
  alias Carddo.{Repo, GameSession}

  @doc """
  Inserts or updates a game session checkpoint.

  `state_json_string` is the raw JSON string returned by the NIF. It is decoded
  to a map before storage because the column is JSONB.

  Returns `{:ok, %GameSession{}}` or `{:error, changeset}`.
  """
  def upsert(room_id, game_id, state_json_string, turn_number)
      when is_binary(state_json_string) do
    state_map = Jason.decode!(state_json_string)

    changeset =
      GameSession.changeset(%GameSession{}, %{
        room_id: room_id,
        game_id: game_id,
        state_json: state_map,
        turn_number: turn_number
      })

    Repo.insert(changeset,
      on_conflict: {:replace, [:state_json, :turn_number, :updated_at]},
      conflict_target: :room_id,
      returning: true
    )
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
    Repo.delete_all(from s in GameSession, where: s.room_id == ^room_id)
  end
end
