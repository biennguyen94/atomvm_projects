defmodule Esp32Temp.Repo.Migrations.CreateTemperatures do
  use Ecto.Migration

  def change do
    create table(:temperatures) do
      add :value, :float

      timestamps(type: :utc_datetime)
    end
  end
end
