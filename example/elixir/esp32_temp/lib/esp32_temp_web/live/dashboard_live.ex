defmodule Esp32TempWeb.DashboardLive do
  use Esp32TempWeb, :live_view

  def mount(_, _, socket) do
    Phoenix.PubSub.subscribe(
      Esp32Temp.PubSub,
      "temperature"
    )

    {:ok, assign(socket, temperature: "--")}
  end

  def handle_info({:temperature_update, temp}, socket) do
    {:noreply,
      assign(socket, temperature: temp)}
  end
end
