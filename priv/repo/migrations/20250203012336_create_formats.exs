defmodule Carddo.Repo.Migrations.CreateFormats do
  use Ecto.Migration

  def change do
    create table(:formats) do
      add :name, :string
      add :description, :string
      add :state_machine, :map
      add :game_id, references(:games, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:formats, [:game_id])
  end
end
