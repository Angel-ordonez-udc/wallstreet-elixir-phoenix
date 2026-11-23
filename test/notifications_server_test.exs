defmodule WallstreetBackend.Notifications.NotificationsServerBasicTest do
  use ExUnit.Case, async: false

  alias WallstreetBackend.Notifications.NotificationsServer

  setup do
    _pid = Process.whereis(NotificationsServer) || start_supervised!({NotificationsServer, []})
    :ok
  end

  test "status returns :ok" do
    assert :ok = NotificationsServer.status()
  end

  test "subscribe_alerts / list_alerts / unsubscribe_alerts" do
    user_id = "notif_user_#{System.unique_integer([:positive])}"

    assert :ok = NotificationsServer.subscribe_alerts(user_id, "BTC", 100.0)

    alerts = NotificationsServer.list_alerts(user_id)
    assert is_list(alerts)
    assert Enum.any?(alerts, &(&1.asset == "BTC"))

    assert :ok = NotificationsServer.unsubscribe_alerts(user_id)
    assert [] == NotificationsServer.list_alerts(user_id)
  end
end
