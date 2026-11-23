defmodule Wallstreet do
  @moduledoc """
  Wall Street — Simulated trading platform.

  Distributed application built with OTP that simulates a stock exchange.
  Allows users to buy and sell assets, view real-time price charts,
  and receive price fluctuation notifications.

  ## Architecture

  The application is organized into the following services, each
  implemented as a supervised GenServer:

    * `WallstreetBackend.Market.MarketServer` — Price simulation
    * `WallstreetBackend.Operations.OperationsServer` — Buy/sell
    * `WallstreetBackend.Graphs.GraphsServer` — Historical data
    * `WallstreetBackend.Notifications.NotificationsServer` — Alerts
    * `WallstreetBackend.Users.UserServer` — User management (dynamic)
  """
end
