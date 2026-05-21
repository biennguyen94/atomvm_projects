defmodule Esp32Temp.MonitorFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Esp32Temp.Monitor` context.
  """

  @doc """
  Generate a temperature.
  """
  def temperature_fixture(attrs \\ %{}) do
    {:ok, temperature} =
      attrs
      |> Enum.into(%{
        value: 120.5
      })
      |> Esp32Temp.Monitor.create_temperature()

    temperature
  end
end
