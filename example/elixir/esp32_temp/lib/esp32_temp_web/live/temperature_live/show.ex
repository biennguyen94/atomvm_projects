defmodule Esp32TempWeb.TemperatureLive.Show do
  use Esp32TempWeb, :live_view

  alias Esp32Temp.Monitor

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Temperature {@temperature.id}
        <:subtitle>This is a temperature record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/temperatures"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/temperatures/#{@temperature}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit temperature
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Value">{@temperature.value}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Temperature")
     |> assign(:temperature, Monitor.get_temperature!(id))}
  end
end
