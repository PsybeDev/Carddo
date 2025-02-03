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

  @doc """
  Generate a format.
  """
  def format_fixture(attrs \\ %{}) do
    {:ok, format} =
      attrs
      |> Enum.into(%{
        description: "some description",
        name: "some name",
        state_machine: %{}
      })
      |> Carddo.Games.create_format()

    format
  end
end
