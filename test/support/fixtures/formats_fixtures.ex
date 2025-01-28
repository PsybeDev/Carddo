defmodule Carddo.FormatsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Carddo.Formats` context.
  """

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
      |> Carddo.Formats.create_format()

    format
  end
end
