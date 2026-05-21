defmodule Esp32TempWeb.TemperatureController do
  use Esp32TempWeb, :controller

  def create(conn, %{"temperature" => temperature}) do
    Phoenix.PubSub.broadcast(
      Esp32Temp.PubSub,
      "temperature",
      {:temperature_update, temperature}
    )

    json(conn, %{status: "ok"})
  end
end
