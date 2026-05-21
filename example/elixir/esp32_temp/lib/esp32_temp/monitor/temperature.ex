defmodule Esp32Temp.Monitor.Temperature do
  use Ecto.Schema
  import Ecto.Changeset

  schema "temperatures" do
    field :value, :float

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(temperature, attrs) do
    temperature
    |> cast(attrs, [:value])
    |> validate_required([:value])
  end
end
