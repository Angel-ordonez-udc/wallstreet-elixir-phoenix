defmodule WallstreetBackend.Operations.OperationsServer do
  @moduledoc """
  Processes buy and sell orders.
  """

  use GenServer
  require Logger

  @behaviour WallstreetBackend.ServiceBehaviour
  @behaviour WallstreetBackend.Operations.OperationsBehaviour

  # ----------------- CLIENT API ----------------------

  @doc """
  Starts the Operations Server.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Executes a buy order for a user.
  """
  @spec buy(String.t(), String.t(), number()) :: {:ok, map()} | {:error, term()}
  @impl WallstreetBackend.Operations.OperationsBehaviour
  def buy(user_id, asset, quantity) do
    GenServer.call(__MODULE__, {:buy, user_id, asset, quantity})
  end

  @doc """
  Executes a sell order for a user.
  """
  @spec sell(String.t(), String.t(), number()) :: {:ok, map()} | {:error, term()}
  @impl WallstreetBackend.Operations.OperationsBehaviour
  def sell(user_id, asset, quantity) do
    GenServer.call(__MODULE__, {:sell, user_id, asset, quantity})
  end

  @doc """
  Retrieves the transaction history for a specific user.
  """
  @spec transaction_history(String.t()) :: {:ok, [map()]}
  @impl WallstreetBackend.Operations.OperationsBehaviour
  def transaction_history(user_id) do
    GenServer.call(__MODULE__, {:history, user_id})
  end

  @doc """
  Returns the current status of the service.
  """
  @spec status() :: :ok
  @impl WallstreetBackend.ServiceBehaviour
  def status, do: GenServer.call(__MODULE__, :status)

  @doc """
  Returns the name of the service.
  """
  @spec service_name() :: String.t()
  @impl WallstreetBackend.ServiceBehaviour
  def service_name, do: "OperationsServer"
  # ---------------------------------------------------

  # -------------- SERVER CALLBACKS -------------------
  @impl GenServer
  def init(_opts) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_call({:buy, user_id, asset, quantity}, _from, state) do
    if quantity <= 0 do
      {:reply, {:error, :invalid_quantity}, state}
    else
      with {:ok, asset_price} <- WallstreetBackend.Repo.get_market_price(asset),
           {:ok, wallet} <- WallstreetBackend.Repo.get_wallet(user_id) do
        total_cost = asset_price * quantity

        if total_cost > wallet.balance do
          {:reply, {:error, :insufficient_funds}, state}
        else
          # Update balance
          case WallstreetBackend.Schemas.Wallet.buy(wallet, asset, quantity, asset_price) do
            {:ok, updated_wallet} ->
              :ok = WallstreetBackend.Repo.update_wallet(user_id, updated_wallet)

              # Register transaction
              transaction = %WallstreetBackend.Operations.Transaction{
                user_id: user_id,
                type: :buy,
                asset: asset,
                quantity: quantity,
                price: asset_price,
                timestamp: DateTime.utc_now()
              }

              persist_transaction(transaction)

              Phoenix.PubSub.broadcast(
                WallstreetBackend.PubSub,
                "transactions",
                {:purchase_completed, user_id, asset, asset_price}
              )

              {:reply, {:ok, transaction}, state}

            {:error, reason} ->
              {:reply, {:error, reason}, state}
          end
        end
      else
        {:error, reason} -> {:reply, {:error, reason}, state}
      end
    end
  end

  @impl GenServer
  def handle_call({:sell, user_id, asset, quantity}, _from, state) do
    if quantity <= 0 do
      {:reply, {:error, :invalid_quantity}, state}
    else
      with {:ok, asset_price} <- WallstreetBackend.Repo.get_market_price(asset),
           {:ok, wallet} <- WallstreetBackend.Repo.get_wallet(user_id) do
        case WallstreetBackend.Schemas.Wallet.sell(wallet, asset, quantity, asset_price) do
          {:ok, updated_wallet} ->
            :ok = WallstreetBackend.Repo.update_wallet(user_id, updated_wallet)

            transaction = %WallstreetBackend.Operations.Transaction{
              user_id: user_id,
              type: :sell,
              asset: asset,
              quantity: quantity,
              price: asset_price,
              timestamp: DateTime.utc_now()
            }

            persist_transaction(transaction)
            {:reply, {:ok, transaction}, state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      else
        {:error, reason} -> {:reply, {:error, reason}, state}
      end
    end
  end

  @impl GenServer
  def handle_call({:history, user_id}, _from, state) do
    {:reply, WallstreetBackend.Repo.get_transactions(user_id), state}
  end

  @impl GenServer
  def handle_call(:status, _from, state) do
    {:reply, :ok, state}
  end

  defp persist_transaction(transaction) do
    case WallstreetBackend.Repo.save_transaction(transaction) do
      :ok -> :ok
      {:error, reason} -> Logger.warning("Transaction persistence failed: #{inspect(reason)}")
    end
  end

  # -----------------------------------------------------
end
