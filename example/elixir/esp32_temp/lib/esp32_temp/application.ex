defmodule Esp32Temp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Esp32TempWeb.Telemetry,
      Esp32Temp.Repo,
      {DNSCluster, query: Application.get_env(:esp32_temp, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Esp32Temp.PubSub},
      # Start a worker by calling: Esp32Temp.Worker.start_link(arg)
      # {Esp32Temp.Worker, arg},
      # Start to serve requests, typically the last entry
      Esp32TempWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Esp32Temp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    Esp32TempWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
