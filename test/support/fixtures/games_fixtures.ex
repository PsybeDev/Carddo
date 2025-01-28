defmodule Carddo.GamesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Carddo.Games` context.
  """

  @doc """
  Generate a game.
  """
  def game_fixture(attrs \\ %{}) do
    {:ok, game} =
      attrs
      |> Enum.into(%{
        description: "some description",
        name: "some name",
        state_machine: %{}
      })
      |> Carddo.Games.create_game()

    game
  end
end
