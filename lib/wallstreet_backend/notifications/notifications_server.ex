defmodule WallstreetBackend.Notifications.NotificationsServer do
  @moduledoc """
  Listens to Market PubSub events. For each tick, evaluates whether any
  subscribed user has an alert that should be triggered.
  """

  use GenServer
  require Logger

  @behaviour WallstreetBackend.ServiceBehaviour
  @behaviour WallstreetBackend.Notifications.NotificationsBehaviour

  # State: %{user_id => [%{asset: ..., purchase_price: ..., notified: false}]}

  # ----------------- CLIENT API ----------------------
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl WallstreetBackend.Notifications.NotificationsBehaviour
  def subscribe_alerts(user_id, asset, purchase_price) do
    GenServer.call(__MODULE__, {:subscribe, user_id, asset, purchase_price})
  end

  @impl WallstreetBackend.Notifications.NotificationsBehaviour
  def unsubscribe_alerts(user_id) do
    GenServer.call(__MODULE__, {:unsubscribe, user_id})
  end

  @impl WallstreetBackend.Notifications.NotificationsBehaviour
  def list_alerts(user_id) do
    GenServer.call(__MODULE__, {:list_alerts, user_id})
  end

  @doc """
  Subscribes the calling process to a user's personal alerts.
  """
  def subscribe_user_alerts(user_id) do
    Phoenix.PubSub.subscribe(WallstreetBackend.PubSub, "user:#{user_id}:alerts")
  end

  @impl WallstreetBackend.ServiceBehaviour
  def status, do: GenServer.call(__MODULE__, :status)

  @impl WallstreetBackend.ServiceBehaviour
  def service_name, do: "NotificationsServer"
  # ---------------------------------------------------

  # -------------- SERVER CALLBACKS -------------------
  @impl GenServer
  def init(_opts) do
    Phoenix.PubSub.subscribe(WallstreetBackend.PubSub, "market:prices")
    Phoenix.PubSub.subscribe(WallstreetBackend.PubSub, "transactions")
    {:ok, %{}}
  end

  @impl GenServer
  def handle_call({:subscribe, user_id, asset, purchase_price}, _from, state) do
    alerts = Map.get(state, user_id, [])
    new_alert = %{asset: asset, purchase_price: purchase_price, notified: false}
    new_state = Map.put(state, user_id, [new_alert | alerts])
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:unsubscribe, user_id}, _from, state) do
    new_state = Map.delete(state, user_id)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:list_alerts, user_id}, _from, state) do
    {:reply, Map.get(state, user_id, []), state}
  end

  @impl GenServer
  def handle_call(:status, _from, state) do
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info({:price_tick, asset, current_price}, state) do
    new_state =
      Enum.reduce(state, %{}, fn {user_id, alerts}, acc ->
        new_alerts =
          Enum.map(alerts, fn alert ->
            if alert.asset == asset do
              change = (current_price - alert.purchase_price) / alert.purchase_price

              cond do
                abs(change) >= 0.05 and not alert.notified ->
                  Logger.info(
                    "[NOTIFICATION] User #{user_id}: Asset #{asset} has changed more than 5% (#{current_price})"
                  )

                  Phoenix.PubSub.broadcast(
                    WallstreetBackend.PubSub,
                    "user:#{user_id}:alerts",
                    {:alert, %{asset: asset, current_price: current_price, change: change}}
                  )

                  %{alert | notified: true}

                abs(change) < 0.05 and alert.notified ->
                  # Reset notification so it can be triggered again
                  %{alert | notified: false}

                true ->
                  alert
              end
            else
              alert
            end
          end)

        Map.put(acc, user_id, new_alerts)
      end)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({:purchase_completed, user_id, asset, purchase_price}, state) do
    state_without_user = Map.delete(state, user_id)
    new_alert = %{asset: asset, purchase_price: purchase_price, notified: false}
    new_state = Map.put(state_without_user, user_id, [new_alert])
    {:noreply, new_state}
  end

  # ---------------------------------------------------
end
