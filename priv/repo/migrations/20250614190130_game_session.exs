defmodule Carddo.Repo.Migrations.GameSession do
  use Ecto.Migration

  def change do
    create table(:game_sessions) do
      add :state, :string, default: "pending"
      add :current_turn, :integer, default: 0
      add :current_player_id, :integer
      add :game_data, :map, default: %{}
      add :format_id, references(:formats, on_delete: :nothing)
      add :game_id, references(:games, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:game_sessions, [:game_id])

    create table(:games_players) do
      add :hand, {:array, :map}, default: []
      add :deck, {:array, :map}, default: []
      add :discard_pile, {:array, :map}, default: []
      add :play_area, {:array, :map}, default: []
      add :mana, :integer, default: 0
      add :life_points, :integer, default: 20
      add :user_id, references(:users, on_delete: :nothing)
      add :game_session_id, references(:game_sessions, on_delete: :delete_all)
      timestamps(type: :utc_datetime)
    end

    create index(:games_players, [:game_session_id])

    create table(:cards) do
      add :name, :string
      add :description, :string
      add :type, :string
      add :cost, :integer, default: 0
      add :power, :integer, default: 0
      add :toughness, :integer, default: 0
      add :abilities, {:array, :map}, default: []
      add :game_id, references(:games, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:cards, [:game_id])

  end
end
