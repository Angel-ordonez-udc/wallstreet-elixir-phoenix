defmodule WallstreetBackend.Directorio do
  @moduledoc """
  System facade (Facade pattern).

  Single entry point that delegates requests to the corresponding services.
  """
  use GenServer

  alias WallstreetBackend.Market.MarketServer
  alias WallstreetBackend.Operations.OperationsServer
  alias WallstreetBackend.Graphs.GraphsServer
  alias WallstreetBackend.Notifications.NotificationsServer
  alias WallstreetBackend.Users.UserServer
  alias WallstreetBackend.Users.UserSupervisor

  # API for Supervisor
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  # -------------- MARKET --------------

  @doc "Gets the current price of an asset."
  defdelegate current_price(asset), to: MarketServer

  @doc "Subscribes the calling process to market price updates."
  defdelegate subscribe_market_updates, to: MarketServer, as: :subscribe

  # -------------- OPERATIONS --------------

  @doc "Executes a buy order."
  defdelegate buy(user_id, asset, quantity), to: OperationsServer

  @doc "Executes a sell order."
  defdelegate sell(user_id, asset, quantity), to: OperationsServer

  @doc "Gets the transaction history for a user."
  defdelegate transaction_history(user_id), to: OperationsServer

  # -------------- GRAPHS --------------

  @doc "Retrieves historical price data."
  defdelegate historic(start_date, end_date), to: GraphsServer

  @doc "Retrieves OHLC data grouped by interval."
  defdelegate ohlc(start_date, end_date, interval), to: GraphsServer

  # -------------- NOTIFICATIONS --------------

  @doc "Subscribes a user to price alerts."
  defdelegate subscribe_alerts(user_id, asset, threshold), to: NotificationsServer

  @doc "Unsubscribes a user from price alerts."
  defdelegate unsubscribe_alerts(user_id), to: NotificationsServer

  @doc "Subscribes the calling process to a user's personal alerts."
  defdelegate subscribe_user_alerts(user_id), to: NotificationsServer

  # -------------- USERS --------------

  @doc "Registers a new user."
  defdelegate register(user_id, credentials), to: UserSupervisor, as: :register_user

  @doc "Logs in an existing user (starts their process)."
  defdelegate login(user_id, credentials), to: UserSupervisor, as: :login_user

  @doc "Logs out a user (stops their process)."
  defdelegate logout(user_id), to: UserSupervisor, as: :stop_user

  @doc "Gets the current wallet for a user."
  defdelegate get_wallet(user_id), to: UserServer

  @doc "Gets the available balance for a user."
  defdelegate get_balance(user_id), to: UserServer
end
