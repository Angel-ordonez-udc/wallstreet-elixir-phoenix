defmodule WallstreetBackend.Storage.MnesiaStorage do
  @moduledoc """
  Persistence adapter for wallets and transactions using Mnesia.
  """

  alias WallstreetBackend.Operations.Transaction

  @wallets :wallets
  @transactions :transactions

  @spec setup() :: :ok | {:error, term()}
  def setup do
    with :ok <- ensure_schema(),
         :ok <- ensure_started(),
         :ok <- ensure_tables() do
      :ok
    end
  end

  # WALLETS TABLE
  @spec save_wallet(String.t(), term()) :: :ok | {:error, term()}
  def save_wallet(user_id, wallet) do
    with_ready(fn ->
      case :mnesia.transaction(fn ->
             :mnesia.write({@wallets, user_id, wallet})
           end) do
        {:atomic, :ok} -> :ok
        {:aborted, reason} -> {:error, reason}
      end
    end)
  end

  @spec get_wallet(String.t()) :: {:ok, term()} | {:error, :wallet_not_found}
  def get_wallet(user_id) do
    with_ready(fn ->
      case :mnesia.transaction(fn -> :mnesia.read(@wallets, user_id) end) do
        {:atomic, [{@wallets, ^user_id, wallet}]} ->
          {:ok, wallet}

        {:atomic, []} ->
          {:error, :wallet_not_found}

        {:aborted, _reason} ->
          {:error, :wallet_not_found}
      end
    end)
  end

  # TRANSACTIONS TABLE
  @spec save_transaction(Transaction.t()) :: :ok | {:error, term()}
  def save_transaction(%Transaction{} = transaction) do
    tx_id = System.unique_integer([:positive, :monotonic])

    with_ready(fn ->
      case :mnesia.transaction(fn ->
             :mnesia.write(
               {@transactions, tx_id, transaction.user_id, transaction.type, transaction.asset,
                transaction.quantity, transaction.price, transaction.timestamp}
             )
           end) do
        {:atomic, :ok} -> :ok
        {:aborted, reason} -> {:error, reason}
      end
    end)
  end

  @spec get_transactions(String.t()) :: {:ok, [Transaction.t()]} | {:error, term()}
  def get_transactions(user_id) do
    case with_ready(fn ->
           case :mnesia.transaction(fn ->
                  :mnesia.match_object({@transactions, :_, user_id, :_, :_, :_, :_, :_})
                end) do
             {:atomic, records} ->
               transactions =
                 records
                 |> Enum.map(fn {@transactions, _id, tx_user_id, type, asset, quantity, price,
                                 timestamp} ->
                   %Transaction{
                     user_id: tx_user_id,
                     type: type,
                     asset: asset,
                     quantity: quantity,
                     price: price,
                     timestamp: timestamp
                   }
                 end)
                 |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})

               {:ok, transactions}

             {:aborted, reason} ->
               {:error, reason}
           end
         end) do
      {:error, _reason} -> {:ok, []}
      response -> response
    end
  end

  # --- Mnesia table setup helpers ---
  defp ensure_schema do
    case :mnesia.create_schema([node()]) do
      :ok -> :ok
      {:error, {_, {:already_exists, _}}} -> :ok
      {:error, {_, {_, {:already_exists, _}}}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_started do
    case :mnesia.start() do
      :ok -> :ok
      {:error, {:already_started, :mnesia}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_tables do
    with :ok <- create_wallets_table(),
         :ok <- create_transactions_table(),
         :ok <- wait_for_tables() do
      :ok
    end
  end

  defp create_wallets_table do
    create_table_with_fallback(@wallets, [{:attributes, [:user_id, :wallet]}])
  end

  defp create_transactions_table do
    create_table_with_fallback(@transactions, [
      {:attributes, [:id, :user_id, :type, :asset, :quantity, :price, :timestamp]},
      {:type, :ordered_set}
    ])
  end

  defp wait_for_tables do
    case :mnesia.wait_for_tables([@wallets, @transactions], 5_000) do
      :ok -> :ok
      {:timeout, _tables} = timeout -> {:error, timeout}
    end
  end

  defp copy_mode_option do
    case node() do
      :nonode@nohost -> {:ram_copies, [node()]}
      _other -> {:disc_copies, [node()]}
    end
  end

  defp create_table_with_fallback(table, base_options) do
    preferred = base_options ++ [copy_mode_option()]

    case :mnesia.create_table(table, preferred) do
      {:atomic, :ok} ->
        :ok

      {:aborted, {:already_exists, ^table}} ->
        :ok

      {:aborted, {:bad_type, ^table, :disc_copies, _node}} ->
        fix_schema_for_disc_copies_and_retry(table, base_options)

      {:aborted, reason} ->
        {:error, reason}
    end
  end

  defp fix_schema_for_disc_copies_and_retry(table, base_options) do
    with :stopped <- :mnesia.stop(),
         :ok <- drop_schema_if_exists(),
         :ok <- create_schema_for_current_node(),
         :ok <- ensure_started() do
      case :mnesia.create_table(table, base_options ++ [{:disc_copies, [node()]}]) do
        {:atomic, :ok} -> :ok
        {:aborted, {:already_exists, ^table}} -> :ok
        {:aborted, reason} -> {:error, reason}
      end
    else
      {:error, reason} ->
        create_table_ram_fallback(table, base_options, reason)

      other ->
        create_table_ram_fallback(table, base_options, other)
    end
  end

  defp drop_schema_if_exists do
    case :mnesia.delete_schema([node()]) do
      :ok -> :ok
      {:error, {_, {:no_exists, _}}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_schema_for_current_node do
    case :mnesia.create_schema([node()]) do
      :ok -> :ok
      {:error, {_, {:already_exists, _}}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_table_ram_fallback(table, base_options, _reason) do
    case :mnesia.create_table(table, base_options ++ [{:ram_copies, [node()]}]) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, ^table}} -> :ok
      {:aborted, reason} -> {:error, reason}
    end
  end

  defp with_ready(fun) when is_function(fun, 0) do
    case setup() do
      :ok -> fun.()
      {:error, reason} -> {:error, reason}
    end
  end
end
