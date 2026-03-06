defmodule Carddo.Repo.Migrations.AddConfigToGames do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :config, :map, null: false, default: %{}
    end
  end
end
