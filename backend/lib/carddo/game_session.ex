defmodule Carddo.GameSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @timestamps_opts [type: :naive_datetime, updated_at: :updated_at, inserted_at: false]

  schema "game_sessions" do
    field :room_id, :string
    field :game_id, :binary_id
    field :state_json, :map
    field :turn_number, :integer

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:room_id, :game_id, :state_json, :turn_number])
    |> validate_required([:room_id, :game_id, :state_json, :turn_number])
  end
end
