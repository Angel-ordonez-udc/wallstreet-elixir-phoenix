defmodule WallstreetBackend.Repo do
  @moduledoc """
  In-memory repository for wallets, transactions and market state.

  Acts as the single point of truth (Repository Pattern) for data access.
  """

  use GenServer
  require Logger

  @behaviour WallstreetBackend.RepositoryBehaviour

  alias WallstreetBackend.Operations.Transaction
  alias WallstreetBackend.Schemas.Wallet
  alias WallstreetBackend.Storage.MnesiaStorage

  @default_balance 10_000.0

  # ----------------- CLIENT API ----------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates an initial wallet for a new user.
  Called by UserSupervisor after registering user credentials.
  """
  @spec create_wallet(String.t()) :: :ok | {:error, :wallet_already_exists}
  def create_wallet(user_id) when is_binary(user_id) do
    GenServer.call(__MODULE__, {:create_wallet, user_id})
  end

  @spec get_wallet(String.t()) :: {:ok, Wallet.t()} | {:error, :user_not_found}
  @impl true
  def get_wallet(user_id) when is_binary(user_id) do
    GenServer.call(__MODULE__, {:get_wallet, user_id})
  end

  @spec update_wallet(String.t(), Wallet.t()) :: :ok | {:error, :user_not_found}
  @impl true
  def update_wallet(user_id, wallet) when is_binary(user_id) do
    GenServer.call(__MODULE__, {:update_wallet, user_id, wallet})
  end

  @doc """
  Gets the current price for an asset.
  """
  @impl true
  def get_market_price(asset) do
    GenServer.call(__MODULE__, {:get_market_price, asset})
  end

  @doc """
  Gets all listed asset names.
  """
  @impl true
  def get_market_prices() do
    GenServer.call(__MODULE__, :get_market_prices)
  end

  @doc """
  Updates the market price for an asset. Used by MarketServer to notify the repository of new ticks.
  """
  @impl true
  def update_market_price(asset, price) when is_binary(asset) and is_number(price) do
    GenServer.cast(__MODULE__, {:update_market_price, asset, price})
  end

  @spec save_transaction(Transaction.t()) :: :ok | {:error, term()}
  def save_transaction(%Transaction{} = transaction) do
    GenServer.call(__MODULE__, {:save_transaction, transaction})
  end

  @spec get_transactions(String.t()) :: {:ok, [Transaction.t()]} | {:error, term()}
  def get_transactions(user_id) when is_binary(user_id) do
    GenServer.call(__MODULE__, {:get_transactions, user_id})
  end

  # ---------------------------------------------------

  # -------------- SERVER CALLBACKS -------------------

  @impl GenServer
  def init(_opts) do
    case MnesiaStorage.setup() do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Mnesia setup failed, continuing in-memory: #{inspect(reason)}")
    end

    {:ok, %{market_prices: %{}}}
  end

  @impl GenServer
  def handle_call({:create_wallet, user_id}, _from, state) do
    case MnesiaStorage.get_wallet(user_id) do
      {:ok, _wallet} ->
        {:reply, {:error, :wallet_already_exists}, state}

      {:error, _} ->
        wallet = Wallet.new(@default_balance)
        :ok = MnesiaStorage.save_wallet(user_id, wallet)
        {:reply, :ok, state}
    end
  end

  @impl GenServer
  def handle_call({:get_wallet, user_id}, _from, state) do
    case MnesiaStorage.get_wallet(user_id) do
      {:ok, wallet} -> {:reply, {:ok, wallet}, state}
      {:error, _} -> {:reply, {:error, :user_not_found}, state}
    end
  end

  @impl GenServer
  def handle_call({:update_wallet, user_id, wallet}, _from, state) do
    case MnesiaStorage.get_wallet(user_id) do
      {:ok, _existing} ->
        :ok = MnesiaStorage.save_wallet(user_id, wallet)
        {:reply, :ok, state}

      {:error, _} ->
        {:reply, {:error, :user_not_found}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_market_price, asset}, _from, state) do
    case Map.get(state.market_prices, asset) do
      nil -> {:reply, {:error, :asset_not_found}, state}
      price -> {:reply, {:ok, price}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_market_prices, _from, state) do
    {:reply, Map.keys(state.market_prices), state}
  end

  @impl GenServer
  def handle_call({:save_transaction, transaction}, _from, state) do
    {:reply, MnesiaStorage.save_transaction(transaction), state}
  end

  @impl GenServer
  def handle_call({:get_transactions, user_id}, _from, state) do
    {:reply, MnesiaStorage.get_transactions(user_id), state}
  end

  @impl GenServer
  def handle_cast({:update_market_price, asset, price}, state) do
    new_market_prices = Map.put(state.market_prices, asset, price)
    {:noreply, %{state | market_prices: new_market_prices}}
  end
end
