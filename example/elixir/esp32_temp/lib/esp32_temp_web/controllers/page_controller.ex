defmodule Esp32TempWeb.PageController do
  use Esp32TempWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
