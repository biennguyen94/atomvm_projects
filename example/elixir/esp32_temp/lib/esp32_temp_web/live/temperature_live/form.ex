defmodule Esp32TempWeb.TemperatureLive.Form do
  use Esp32TempWeb, :live_view

  alias Esp32Temp.Monitor
  alias Esp32Temp.Monitor.Temperature

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage temperature records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="temperature-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:value]} type="number" label="Value" step="any" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Temperature</.button>
          <.button navigate={return_path(@return_to, @temperature)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    temperature = Monitor.get_temperature!(id)

    socket
    |> assign(:page_title, "Edit Temperature")
    |> assign(:temperature, temperature)
    |> assign(:form, to_form(Monitor.change_temperature(temperature)))
  end

  defp apply_action(socket, :new, _params) do
    temperature = %Temperature{}

    socket
    |> assign(:page_title, "New Temperature")
    |> assign(:temperature, temperature)
    |> assign(:form, to_form(Monitor.change_temperature(temperature)))
  end

  @impl true
  def handle_event("validate", %{"temperature" => temperature_params}, socket) do
    changeset = Monitor.change_temperature(socket.assigns.temperature, temperature_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"temperature" => temperature_params}, socket) do
    save_temperature(socket, socket.assigns.live_action, temperature_params)
  end

  defp save_temperature(socket, :edit, temperature_params) do
    case Monitor.update_temperature(socket.assigns.temperature, temperature_params) do
      {:ok, temperature} ->
        {:noreply,
         socket
         |> put_flash(:info, "Temperature updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, temperature))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_temperature(socket, :new, temperature_params) do
    case Monitor.create_temperature(temperature_params) do
      {:ok, temperature} ->
        {:noreply,
         socket
         |> put_flash(:info, "Temperature created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, temperature))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _temperature), do: ~p"/temperatures"
  defp return_path("show", temperature), do: ~p"/temperatures/#{temperature}"
end
