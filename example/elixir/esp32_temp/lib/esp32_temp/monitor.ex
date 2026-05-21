defmodule Esp32Temp.Monitor do
  @moduledoc """
  The Monitor context.
  """

  import Ecto.Query, warn: false
  alias Esp32Temp.Repo

  alias Esp32Temp.Monitor.Temperature

  @doc """
  Returns the list of temperatures.

  ## Examples

      iex> list_temperatures()
      [%Temperature{}, ...]

  """
  def list_temperatures do
    Repo.all(Temperature)
  end

  @doc """
  Gets a single temperature.

  Raises `Ecto.NoResultsError` if the Temperature does not exist.

  ## Examples

      iex> get_temperature!(123)
      %Temperature{}

      iex> get_temperature!(456)
      ** (Ecto.NoResultsError)

  """
  def get_temperature!(id), do: Repo.get!(Temperature, id)

  @doc """
  Creates a temperature.

  ## Examples

      iex> create_temperature(%{field: value})
      {:ok, %Temperature{}}

      iex> create_temperature(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_temperature(attrs) do
    %Temperature{}
    |> Temperature.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a temperature.

  ## Examples

      iex> update_temperature(temperature, %{field: new_value})
      {:ok, %Temperature{}}

      iex> update_temperature(temperature, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_temperature(%Temperature{} = temperature, attrs) do
    temperature
    |> Temperature.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a temperature.

  ## Examples

      iex> delete_temperature(temperature)
      {:ok, %Temperature{}}

      iex> delete_temperature(temperature)
      {:error, %Ecto.Changeset{}}

  """
  def delete_temperature(%Temperature{} = temperature) do
    Repo.delete(temperature)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking temperature changes.

  ## Examples

      iex> change_temperature(temperature)
      %Ecto.Changeset{data: %Temperature{}}

  """
  def change_temperature(%Temperature{} = temperature, attrs \\ %{}) do
    Temperature.changeset(temperature, attrs)
  end
end
