defmodule WallstreetBackend.Application do
  @moduledoc """
  Application module. Defines the root supervision tree that starts all services on application boot.
  """
  use Application

  def start(_type, _args) do
    children = [
      WallstreetBackend.Repo,
      {Registry, keys: :unique, name: WallstreetBackend.UserRegistry},
      WallstreetBackend.Users.UserSupervisor,
      {Phoenix.PubSub, name: WallstreetBackend.PubSub},
      WallstreetBackend.Directorio,
      WallstreetBackend.Market.MarketServer,
      WallstreetBackend.Graphs.GraphsServer,
      WallstreetBackend.Operations.OperationsServer,
      WallstreetBackend.Notifications.NotificationsServer,
      WallstreetFrontend.Endpoint
    ]

    opts = [strategy: :one_for_one, name: WallstreetBackend.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
