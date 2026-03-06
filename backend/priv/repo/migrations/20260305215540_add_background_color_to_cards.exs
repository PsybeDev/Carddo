defmodule Carddo.Repo.Migrations.AddBackgroundColorToCards do
  use Ecto.Migration

  def change do
    alter table(:cards) do
      add :background_color, :string
    end
  end
end
