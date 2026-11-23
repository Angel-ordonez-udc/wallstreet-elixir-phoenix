defmodule WallstreetBackend.Users.UserSupervisor do
  @moduledoc """
  Dynamic supervisor for user processes.
  """

  use DynamicSupervisor

  alias WallstreetBackend.Repo
  alias WallstreetBackend.Users.Storage
  alias WallstreetBackend.Users.UserServer

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Storage.setup()
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Registers a new user.
  """
  @spec register_user(String.t(), map()) :: :ok | {:error, :user_already_exists}
  def register_user(user_id, credentials) when is_binary(user_id) and is_map(credentials) do
    case Storage.get_user(user_id) do
      {:ok, _} ->
        {:error, :user_already_exists}

      {:error, :user_not_found} ->
        :ok = Storage.save_user(user_id, credentials)
        :ok = Repo.create_wallet(user_id)
        :ok
    end
  end

  @doc """
  Logs in an existing user and starts its process if needed.
  """
  @spec login_user(String.t(), map()) ::
          {:ok, pid()} | {:error, :invalid_credentials | :user_not_found}
  def login_user(user_id, credentials) when is_binary(user_id) and is_map(credentials) do
    case Storage.get_user(user_id) do
      {:ok, %{credentials: ^credentials}} ->
        case Registry.lookup(WallstreetBackend.UserRegistry, user_id) do
          [{pid, _value}] ->
            {:ok, pid}

          [] ->
            spec = {UserServer, {user_id, credentials}}
            DynamicSupervisor.start_child(__MODULE__, spec)
        end

      {:ok, %{credentials: _other}} ->
        {:error, :invalid_credentials}

      {:error, _} ->
        {:error, :user_not_found}
    end
  end

  @doc """
  Stops a user process.
  """
  @spec stop_user(String.t()) :: :ok | {:error, :not_found}
  def stop_user(user_id) when is_binary(user_id) do
    case Registry.lookup(WallstreetBackend.UserRegistry, user_id) do
      [{pid, _value}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)

      [] ->
        {:error, :not_found}
    end
  end
end
