defmodule Carddo.GamesTest do
  use Carddo.DataCase

  alias Carddo.Games

  describe "games" do
    alias Carddo.Games.Game

    import Carddo.GamesFixtures

    @invalid_attrs %{name: nil, description: nil, state_machine: nil}

    test "list_games/0 returns all games" do
      game = game_fixture()
      assert Games.list_games() == [game]
    end

    test "get_game!/1 returns the game with given id" do
      game = game_fixture()
      assert Games.get_game!(game.id) == game
    end

    test "create_game/1 with valid data creates a game" do
      valid_attrs = %{name: "some name", description: "some description", state_machine: %{}}

      assert {:ok, %Game{} = game} = Games.create_game(valid_attrs)
      assert game.name == "some name"
      assert game.description == "some description"
      assert game.state_machine == %{}
    end

    test "create_game/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Games.create_game(@invalid_attrs)
    end

    test "update_game/2 with valid data updates the game" do
      game = game_fixture()
      update_attrs = %{name: "some updated name", description: "some updated description", state_machine: %{}}

      assert {:ok, %Game{} = game} = Games.update_game(game, update_attrs)
      assert game.name == "some updated name"
      assert game.description == "some updated description"
      assert game.state_machine == %{}
    end

    test "update_game/2 with invalid data returns error changeset" do
      game = game_fixture()
      assert {:error, %Ecto.Changeset{}} = Games.update_game(game, @invalid_attrs)
      assert game == Games.get_game!(game.id)
    end

    test "delete_game/1 deletes the game" do
      game = game_fixture()
      assert {:ok, %Game{}} = Games.delete_game(game)
      assert_raise Ecto.NoResultsError, fn -> Games.get_game!(game.id) end
    end

    test "change_game/1 returns a game changeset" do
      game = game_fixture()
      assert %Ecto.Changeset{} = Games.change_game(game)
    end
  end

  describe "formats" do
    alias Carddo.Games.Format

    import Carddo.GamesFixtures

    @invalid_attrs %{name: nil, description: nil, state_machine: nil}

    test "list_formats/0 returns all formats" do
      format = format_fixture()
      assert Games.list_formats() == [format]
    end

    test "get_format!/1 returns the format with given id" do
      format = format_fixture()
      assert Games.get_format!(format.id) == format
    end

    test "create_format/1 with valid data creates a format" do
      valid_attrs = %{name: "some name", description: "some description", state_machine: %{}}

      assert {:ok, %Format{} = format} = Games.create_format(valid_attrs)
      assert format.name == "some name"
      assert format.description == "some description"
      assert format.state_machine == %{}
    end

    test "create_format/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Games.create_format(@invalid_attrs)
    end

    test "update_format/2 with valid data updates the format" do
      format = format_fixture()
      update_attrs = %{name: "some updated name", description: "some updated description", state_machine: %{}}

      assert {:ok, %Format{} = format} = Games.update_format(format, update_attrs)
      assert format.name == "some updated name"
      assert format.description == "some updated description"
      assert format.state_machine == %{}
    end

    test "update_format/2 with invalid data returns error changeset" do
      format = format_fixture()
      assert {:error, %Ecto.Changeset{}} = Games.update_format(format, @invalid_attrs)
      assert format == Games.get_format!(format.id)
    end

    test "delete_format/1 deletes the format" do
      format = format_fixture()
      assert {:ok, %Format{}} = Games.delete_format(format)
      assert_raise Ecto.NoResultsError, fn -> Games.get_format!(format.id) end
    end

    test "change_format/1 returns a format changeset" do
      format = format_fixture()
      assert %Ecto.Changeset{} = Games.change_format(format)
    end
  end
end
