defmodule Esp32TempWeb.ErrorJSONTest do
  use Esp32TempWeb.ConnCase, async: true

  test "renders 404" do
    assert Esp32TempWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert Esp32TempWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
