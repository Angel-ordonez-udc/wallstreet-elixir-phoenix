defmodule WallstreetBackend.Notifications.NotificationsServerTest do
  use ExUnit.Case, async: false

  alias WallstreetBackend.Notifications.NotificationsServer

  setup do
    _pid = Process.whereis(NotificationsServer) || start_supervised!({NotificationsServer, []})
    :ok
  end

  test "subscribe_alerts/3 and list_alerts/1" do
    user_id = "notif_user_#{System.unique_integer([:positive])}"

    assert :ok = NotificationsServer.subscribe_alerts(user_id, "BTC", 100.0)

    alerts = NotificationsServer.list_alerts(user_id)
    assert is_list(alerts)
    assert length(alerts) == 1

    [alert] = alerts
    assert alert.asset == "BTC"
    assert alert.purchase_price == 100.0
    assert alert.notified == false
  end

  test "unsubscribe_alerts/1 clears alerts" do
    user_id = "notif_user_#{System.unique_integer([:positive])}"

    assert :ok = NotificationsServer.subscribe_alerts(user_id, "BTC", 100.0)
    assert :ok = NotificationsServer.unsubscribe_alerts(user_id)
    assert NotificationsServer.list_alerts(user_id) == []
  end

  test "broadcasts alert over pubsub when change >= 5% and sets notified" do
    user_id = "notif_user_#{System.unique_integer([:positive])}"

    Phoenix.PubSub.subscribe(WallstreetBackend.PubSub, "user:#{user_id}:alerts")

    assert :ok = NotificationsServer.subscribe_alerts(user_id, "BTC", 100.0)

    # Trigger +6%
    send(Process.whereis(NotificationsServer), {:price_tick, "BTC", 106.0})

    assert_receive {:alert, %{asset: "BTC", current_price: 106.0, change: change}}, 500
    assert change >= 0.05

    [alert] = NotificationsServer.list_alerts(user_id)
    assert alert.notified == true
  end

  test "does not rebroadcast while notified, but resets when back under threshold" do
    user_id = "notif_user_#{System.unique_integer([:positive])}"

    Phoenix.PubSub.subscribe(WallstreetBackend.PubSub, "user:#{user_id}:alerts")

    assert :ok = NotificationsServer.subscribe_alerts(user_id, "BTC", 100.0)

    # Trigger first notification
    send(Process.whereis(NotificationsServer), {:price_tick, "BTC", 106.0})
    assert_receive {:alert, _}, 500

    # Same direction still above threshold -> should not rebroadcast
    send(Process.whereis(NotificationsServer), {:price_tick, "BTC", 107.0})
    refute_receive {:alert, _}, 150

    # Back within threshold -> resets
    send(Process.whereis(NotificationsServer), {:price_tick, "BTC", 102.0})
    Process.sleep(10)

    [alert] = NotificationsServer.list_alerts(user_id)
    assert alert.notified == false

    # Above threshold again -> should broadcast again
    send(Process.whereis(NotificationsServer), {:price_tick, "BTC", 95.0})
    assert_receive {:alert, %{asset: "BTC", current_price: 95.0}}, 500
  end
end
