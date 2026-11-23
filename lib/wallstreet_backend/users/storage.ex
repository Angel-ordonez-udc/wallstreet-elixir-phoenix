defmodule WallstreetBackend.Users.Storage do
  @moduledoc """
  Persistence adapter for user credentials using Mnesia.
  This is the user service's own database, separate from the
  repository's databases for wallets and transactions.
  """

  @users :users

  @spec setup() :: :ok | {:error, term()}
  def setup do
    with :ok <- ensure_schema(),
         :ok <- ensure_started(),
         :ok <- create_users_table(),
         :ok <- wait_for_tables() do
      :ok
    end
  end

  @spec get_all_users() :: {:ok, map()} | {:error, term()}
  def get_all_users do
    with_ready(fn ->
      case :mnesia.transaction(fn -> :mnesia.match_object({@users, :_, :_}) end) do
        {:atomic, records} ->
          users =
            Map.new(records, fn {@users, user_id, credentials} ->
              {user_id, %{credentials: credentials}}
            end)

          {:ok, users}

        {:aborted, reason} ->
          {:error, reason}
      end
    end)
  end

  @spec save_user(String.t(), map()) :: :ok | {:error, term()}
  def save_user(user_id, credentials) do
    with_ready(fn ->
      case :mnesia.transaction(fn ->
             :mnesia.write({@users, user_id, credentials})
           end) do
        {:atomic, :ok} -> :ok
        {:aborted, reason} -> {:error, reason}
      end
    end)
  end

  @spec get_user(String.t()) ::
          {:ok, %{credentials: map()}} | {:error, :user_not_found}
  def get_user(user_id) do
    with_ready(fn ->
      case :mnesia.transaction(fn -> :mnesia.read(@users, user_id) end) do
        {:atomic, [{@users, ^user_id, credentials}]} ->
          {:ok, %{credentials: credentials}}

        {:atomic, []} ->
          {:error, :user_not_found}

        {:aborted, _reason} ->
          {:error, :user_not_found}
      end
    end)
  end

  # --- MNESIA HELPERS ---

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

  defp create_users_table do
    opts = [{:attributes, [:user_id, :credentials]} | [copy_mode_option()]]

    case :mnesia.create_table(@users, opts) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, @users}} -> :ok
      {:aborted, reason} -> {:error, reason}
    end
  end

  defp wait_for_tables do
    case :mnesia.wait_for_tables([@users], 5_000) do
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

  defp with_ready(fun) when is_function(fun, 0) do
    case setup() do
      :ok -> fun.()
      {:error, reason} -> {:error, reason}
    end
  end
end
