defmodule Esp32TempWeb.TemperatureLiveTest do
  use Esp32TempWeb.ConnCase

  import Phoenix.LiveViewTest
  import Esp32Temp.MonitorFixtures

  @create_attrs %{value: 120.5}
  @update_attrs %{value: 456.7}
  @invalid_attrs %{value: nil}
  defp create_temperature(_) do
    temperature = temperature_fixture()

    %{temperature: temperature}
  end

  describe "Index" do
    setup [:create_temperature]

    test "lists all temperatures", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/temperatures")

      assert html =~ "Listing Temperatures"
    end

    test "saves new temperature", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/temperatures")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Temperature")
               |> render_click()
               |> follow_redirect(conn, ~p"/temperatures/new")

      assert render(form_live) =~ "New Temperature"

      assert form_live
             |> form("#temperature-form", temperature: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#temperature-form", temperature: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/temperatures")

      html = render(index_live)
      assert html =~ "Temperature created successfully"
    end

    test "updates temperature in listing", %{conn: conn, temperature: temperature} do
      {:ok, index_live, _html} = live(conn, ~p"/temperatures")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#temperatures-#{temperature.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/temperatures/#{temperature}/edit")

      assert render(form_live) =~ "Edit Temperature"

      assert form_live
             |> form("#temperature-form", temperature: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#temperature-form", temperature: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/temperatures")

      html = render(index_live)
      assert html =~ "Temperature updated successfully"
    end

    test "deletes temperature in listing", %{conn: conn, temperature: temperature} do
      {:ok, index_live, _html} = live(conn, ~p"/temperatures")

      assert index_live |> element("#temperatures-#{temperature.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#temperatures-#{temperature.id}")
    end
  end

  describe "Show" do
    setup [:create_temperature]

    test "displays temperature", %{conn: conn, temperature: temperature} do
      {:ok, _show_live, html} = live(conn, ~p"/temperatures/#{temperature}")

      assert html =~ "Show Temperature"
    end

    test "updates temperature and returns to show", %{conn: conn, temperature: temperature} do
      {:ok, show_live, _html} = live(conn, ~p"/temperatures/#{temperature}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/temperatures/#{temperature}/edit?return_to=show")

      assert render(form_live) =~ "Edit Temperature"

      assert form_live
             |> form("#temperature-form", temperature: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#temperature-form", temperature: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/temperatures/#{temperature}")

      html = render(show_live)
      assert html =~ "Temperature updated successfully"
    end
  end
end
