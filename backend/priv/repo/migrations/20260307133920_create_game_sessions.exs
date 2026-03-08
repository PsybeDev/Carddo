defmodule Carddo.Repo.Migrations.CreateGameSessions do
  use Ecto.Migration

  def change do
    create table(:game_sessions, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:room_id, :text, null: false)
      add(:game_id, references(:games, on_delete: :delete_all), null: false)
      add(:state_json, :jsonb, null: false)
      add(:turn_number, :integer, null: false, default: 0)
      add(:updated_at, :naive_datetime, null: false, default: fragment("NOW()"))
    end

    create(unique_index(:game_sessions, [:room_id]))
  end
end
