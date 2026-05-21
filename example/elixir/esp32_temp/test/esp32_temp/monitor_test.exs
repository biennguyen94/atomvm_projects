defmodule Esp32Temp.MonitorTest do
  use Esp32Temp.DataCase

  alias Esp32Temp.Monitor

  describe "temperatures" do
    alias Esp32Temp.Monitor.Temperature

    import Esp32Temp.MonitorFixtures

    @invalid_attrs %{value: nil}

    test "list_temperatures/0 returns all temperatures" do
      temperature = temperature_fixture()
      assert Monitor.list_temperatures() == [temperature]
    end

    test "get_temperature!/1 returns the temperature with given id" do
      temperature = temperature_fixture()
      assert Monitor.get_temperature!(temperature.id) == temperature
    end

    test "create_temperature/1 with valid data creates a temperature" do
      valid_attrs = %{value: 120.5}

      assert {:ok, %Temperature{} = temperature} = Monitor.create_temperature(valid_attrs)
      assert temperature.value == 120.5
    end

    test "create_temperature/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Monitor.create_temperature(@invalid_attrs)
    end

    test "update_temperature/2 with valid data updates the temperature" do
      temperature = temperature_fixture()
      update_attrs = %{value: 456.7}

      assert {:ok, %Temperature{} = temperature} = Monitor.update_temperature(temperature, update_attrs)
      assert temperature.value == 456.7
    end

    test "update_temperature/2 with invalid data returns error changeset" do
      temperature = temperature_fixture()
      assert {:error, %Ecto.Changeset{}} = Monitor.update_temperature(temperature, @invalid_attrs)
      assert temperature == Monitor.get_temperature!(temperature.id)
    end

    test "delete_temperature/1 deletes the temperature" do
      temperature = temperature_fixture()
      assert {:ok, %Temperature{}} = Monitor.delete_temperature(temperature)
      assert_raise Ecto.NoResultsError, fn -> Monitor.get_temperature!(temperature.id) end
    end

    test "change_temperature/1 returns a temperature changeset" do
      temperature = temperature_fixture()
      assert %Ecto.Changeset{} = Monitor.change_temperature(temperature)
    end
  end
end
