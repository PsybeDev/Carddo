defmodule Carddo.FormatsTest do
  use Carddo.DataCase

  alias Carddo.Formats

  describe "formats" do
    alias Carddo.Formats.Format

    import Carddo.FormatsFixtures

    @invalid_attrs %{name: nil, description: nil, state_machine: nil}

    test "list_formats/0 returns all formats" do
      format = format_fixture()
      assert Formats.list_formats() == [format]
    end

    test "get_format!/1 returns the format with given id" do
      format = format_fixture()
      assert Formats.get_format!(format.id) == format
    end

    test "create_format/1 with valid data creates a format" do
      valid_attrs = %{name: "some name", description: "some description", state_machine: %{}}

      assert {:ok, %Format{} = format} = Formats.create_format(valid_attrs)
      assert format.name == "some name"
      assert format.description == "some description"
      assert format.state_machine == %{}
    end

    test "create_format/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Formats.create_format(@invalid_attrs)
    end

    test "update_format/2 with valid data updates the format" do
      format = format_fixture()
      update_attrs = %{name: "some updated name", description: "some updated description", state_machine: %{}}

      assert {:ok, %Format{} = format} = Formats.update_format(format, update_attrs)
      assert format.name == "some updated name"
      assert format.description == "some updated description"
      assert format.state_machine == %{}
    end

    test "update_format/2 with invalid data returns error changeset" do
      format = format_fixture()
      assert {:error, %Ecto.Changeset{}} = Formats.update_format(format, @invalid_attrs)
      assert format == Formats.get_format!(format.id)
    end

    test "delete_format/1 deletes the format" do
      format = format_fixture()
      assert {:ok, %Format{}} = Formats.delete_format(format)
      assert_raise Ecto.NoResultsError, fn -> Formats.get_format!(format.id) end
    end

    test "change_format/1 returns a format changeset" do
      format = format_fixture()
      assert %Ecto.Changeset{} = Formats.change_format(format)
    end
  end
end
