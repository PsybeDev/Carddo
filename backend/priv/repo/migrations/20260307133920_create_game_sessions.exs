defmodule Carddo.Repo.Migrations.CreateGameSessions do
  use Ecto.Migration

  def change do
    create table(:game_sessions) do
      add(:room_id, :text, null: false)
      add(:game_id, references(:games, on_delete: :delete_all), null: false)
      add(:state_json, :jsonb, null: false)
      add(:turn_number, :integer, null: false, default: 0)

      timestamps(updated_at: :updated_at, inserted_at: false)
    end

    create(unique_index(:game_sessions, [:room_id]))
    create(index(:game_sessions, [:game_id]))
  end
end
