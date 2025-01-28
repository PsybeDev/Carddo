defmodule CarddoWeb.FormatLiveTest do
  use CarddoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Carddo.FormatsFixtures

  @create_attrs %{name: "some name", description: "some description", state_machine: %{}}
  @update_attrs %{name: "some updated name", description: "some updated description", state_machine: %{}}
  @invalid_attrs %{name: nil, description: nil, state_machine: nil}

  defp create_format(_) do
    format = format_fixture()
    %{format: format}
  end

  describe "Index" do
    setup [:create_format]

    test "lists all formats", %{conn: conn, format: format} do
      {:ok, _index_live, html} = live(conn, ~p"/formats")

      assert html =~ "Listing Formats"
      assert html =~ format.name
    end

    test "saves new format", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/formats")

      assert index_live |> element("a", "New Format") |> render_click() =~
               "New Format"

      assert_patch(index_live, ~p"/formats/new")

      assert index_live
             |> form("#format-form", format: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#format-form", format: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/formats")

      html = render(index_live)
      assert html =~ "Format created successfully"
      assert html =~ "some name"
    end

    test "updates format in listing", %{conn: conn, format: format} do
      {:ok, index_live, _html} = live(conn, ~p"/formats")

      assert index_live |> element("#formats-#{format.id} a", "Edit") |> render_click() =~
               "Edit Format"

      assert_patch(index_live, ~p"/formats/#{format}/edit")

      assert index_live
             |> form("#format-form", format: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#format-form", format: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/formats")

      html = render(index_live)
      assert html =~ "Format updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes format in listing", %{conn: conn, format: format} do
      {:ok, index_live, _html} = live(conn, ~p"/formats")

      assert index_live |> element("#formats-#{format.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#formats-#{format.id}")
    end
  end

  describe "Show" do
    setup [:create_format]

    test "displays format", %{conn: conn, format: format} do
      {:ok, _show_live, html} = live(conn, ~p"/formats/#{format}")

      assert html =~ "Show Format"
      assert html =~ format.name
    end

    test "updates format within modal", %{conn: conn, format: format} do
      {:ok, show_live, _html} = live(conn, ~p"/formats/#{format}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Format"

      assert_patch(show_live, ~p"/formats/#{format}/show/edit")

      assert show_live
             |> form("#format-form", format: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#format-form", format: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/formats/#{format}")

      html = render(show_live)
      assert html =~ "Format updated successfully"
      assert html =~ "some updated name"
    end
  end
end
