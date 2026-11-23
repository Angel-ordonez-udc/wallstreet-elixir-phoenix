defmodule WallstreetBackend.Users.UserServer do
  @moduledoc """
  One process per user. Saves session status, balance, and reference to their wallet.
  Started dynamically by the `UserSupervisor`.
  """

  use GenServer

  @behaviour WallstreetBackend.Users.UserBehaviour

  alias WallstreetBackend.Repo
  alias WallstreetBackend.Schemas.Wallet
  alias WallstreetBackend.Users.Storage

  # ----------------- CLIENT API ----------------------

  @doc """
  Dynamic name for each process based on its user_id
  """
  def start_link({user_id, _credentials} = init_arg) do
    name = via_tuple(user_id)
    GenServer.start_link(__MODULE__, init_arg, name: name)
  end

  @impl WallstreetBackend.Users.UserBehaviour
  def authenticate(user_id, credentials) do
    GenServer.call(via_tuple(user_id), {:authenticate, credentials})
  end

  @impl WallstreetBackend.Users.UserBehaviour
  def get_wallet(user_id) do
    GenServer.call(via_tuple(user_id), :get_wallet)
  end

  @doc """
  Returns the available cash balance for the user.
  """
  def get_balance(user_id) do
    GenServer.call(via_tuple(user_id), :get_balance)
  end

  # ---------------------------------------------------

  # -------------- SERVER CALLBACKS -------------------
  @impl GenServer
  def init({user_id, _credentials}) do
    state = %{user_id: user_id}
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:authenticate, credentials}, _from, state) do
    case Storage.get_user(state.user_id) do
      {:ok, %{credentials: ^credentials}} ->
        {:reply, {:ok, %{user_id: state.user_id}}, state}

      {:ok, %{credentials: _other}} ->
        {:reply, {:error, :invalid_credentials}, state}

      {:error, _} ->
        {:reply, {:error, :user_not_found}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_wallet, _from, state) do
    case Repo.get_wallet(state.user_id) do
      {:ok, wallet} -> {:reply, {:ok, Wallet.to_quantity_map(wallet)}, state}
      error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call(:get_balance, _from, state) do
    case Repo.get_wallet(state.user_id) do
      {:ok, wallet} -> {:reply, {:ok, wallet.balance}, state}
      error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def terminate(_reason, _state) do
    :ok
  end

  # -----------------------------------------------------

  defp via_tuple(user_id) do
    {:via, Registry, {WallstreetBackend.UserRegistry, user_id}}
  end
end
