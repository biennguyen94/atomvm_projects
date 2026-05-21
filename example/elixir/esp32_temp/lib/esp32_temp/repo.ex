defmodule Esp32Temp.Repo do
  use Ecto.Repo,
    otp_app: :esp32_temp,
    adapter: Ecto.Adapters.Postgres
end
