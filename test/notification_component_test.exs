defmodule WallstreetFrontend.Components.NotificationComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias WallstreetFrontend.Components.NotificationComponent

  test "renders at most 3 notifications" do
    notifications =
      for i <- 1..5 do
        %{
          type: if(rem(i, 2) == 0, do: "subió", else: "bajó"),
          message: "notif-#{i}"
        }
      end

    html = render_component(&NotificationComponent.render/1, notifications: notifications)

    assert html =~ "notif-1"
    assert html =~ "notif-2"
    assert html =~ "notif-3"
    refute html =~ "notif-4"
    refute html =~ "notif-5"
  end

  test "uses green styling for type == subió" do
    notifications = [%{type: "subió", message: "up"}]

    html = render_component(&NotificationComponent.render/1, notifications: notifications)

    assert html =~ "background:#065f46"
    assert html =~ "color:#6ee7b7"
    assert html =~ "up"
  end

  test "uses red styling for other types" do
    notifications = [%{type: "bajó", message: "down"}]

    html = render_component(&NotificationComponent.render/1, notifications: notifications)

    assert html =~ "background:#7f1d1d"
    assert html =~ "color:#fca5a5"
    assert html =~ "down"
  end

  test "renders empty container when notifications is empty" do
    html = render_component(&NotificationComponent.render/1, notifications: [])

    # wrapper div is always present
    assert html =~ "position:fixed"
    refute html =~ "background:#065f46"
    refute html =~ "background:#7f1d1d"
  end

  test "non-subió types fall back to red styling" do
    html =
      render_component(&NotificationComponent.render/1,
        notifications: [%{type: "otro", message: "x"}]
      )

    assert html =~ "background:#7f1d1d"
    assert html =~ "color:#fca5a5"
    assert html =~ "x"
  end

  test "NotificationComponent module is loaded" do
    assert Code.ensure_loaded?(NotificationComponent)
    assert NotificationComponent.__info__(:module) == NotificationComponent
  end
end
