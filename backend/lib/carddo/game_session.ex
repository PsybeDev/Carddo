defmodule Carddo.GameSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, updated_at: :updated_at, inserted_at: false]

  schema "game_sessions" do
    field(:room_id, :string)
    belongs_to(:game, Carddo.Game)
    field(:state_json, :map)
    field(:turn_number, :integer)

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:state_json, :turn_number])
    |> validate_required([:state_json, :turn_number])
  end
end
