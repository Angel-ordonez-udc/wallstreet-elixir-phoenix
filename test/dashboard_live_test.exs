defmodule WallstreetFrontend.DashboardLiveSmokeTest do
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest
  import Phoenix.ConnTest
  import Plug.Conn

  alias WallstreetBackend.Directorio

  @endpoint WallstreetFrontend.Endpoint

  defp session_conn(session) do
    conn =
      build_conn()
      |> Map.put(:secret_key_base, String.duplicate("a", 64))
      |> Plug.Session.call(Plug.Session.init(store: :cookie, key: "_test", signing_salt: "salt"))
      |> fetch_session()

    Enum.reduce(session, conn, fn {k, v}, acc -> put_session(acc, k, v) end)
  end

  defp assert_flash(view, kind, expected_substring) do
    state = :sys.get_state(view.pid)
    flash = state.socket.assigns.flash

    msg = Phoenix.Flash.get(flash, kind)
    assert is_binary(msg)
    assert msg =~ expected_substring
  end

  test "dashboard mounts with a valid session" do
    user_id = "dash_smoke_#{System.unique_integer([:positive])}"
    creds = %{"password" => "pw"}
    :ok = Directorio.register(user_id, creds)

    conn = session_conn(%{"user_id" => user_id, "password" => "pw"})
    {:ok, _view, html} = live(conn, "/dashboard")

    # No fragile assertions on exact text; only check user_id presence
    assert html =~ user_id
  end

  test "dashboard redirects to /login when session is missing" do
    conn = session_conn(%{})
    assert {:error, {:live_redirect, %{to: "/login"}}} = live(conn, "/dashboard")
  end

  describe "DashboardLive events" do
    test "place_order with invalid amount shows flash error" do
      user_id = "dash_evt_#{System.unique_integer([:positive])}"
      creds = %{"password" => "pw"}
      :ok = Directorio.register(user_id, creds)
      {:ok, _pid} = Directorio.login(user_id, creds)

      conn = session_conn(%{"user_id" => user_id, "password" => "pw"})
      {:ok, view, _html} = live(conn, "/dashboard")

      _ =
        view |> form("form[phx-submit=\"place_order\"]", %{"amount" => "nope"}) |> render_submit()

      assert_flash(view, :error, "Cantidad invalida")
    end

    test "place_order insufficient_funds shows flash" do
      user_id = "dash_evt_#{System.unique_integer([:positive])}"
      creds = %{"password" => "pw"}
      :ok = Directorio.register(user_id, creds)
      {:ok, _pid} = Directorio.login(user_id, creds)

      :ok = :meck.new(Directorio, [:passthrough])

      :meck.expect(Directorio, :buy, fn ^user_id, "BTC", _qty -> {:error, :insufficient_funds} end)

      try do
        conn = session_conn(%{"user_id" => user_id, "password" => "pw"})
        {:ok, view, _html} = live(conn, "/dashboard")

        _ =
          view |> form("form[phx-submit=\"place_order\"]", %{"amount" => "10"}) |> render_submit()

        assert_flash(view, :error, "Fondos insuficientes")
      after
        :meck.unload(Directorio)
      end
    end

    test "place_order insufficient_assets shows flash (sell)" do
      user_id = "dash_evt_#{System.unique_integer([:positive])}"
      creds = %{"password" => "pw"}
      :ok = Directorio.register(user_id, creds)
      {:ok, _pid} = Directorio.login(user_id, creds)

      :ok = :meck.new(Directorio, [:passthrough])

      :meck.expect(Directorio, :sell, fn ^user_id, "BTC", _qty ->
        {:error, :insufficient_assets}
      end)

      try do
        conn = session_conn(%{"user_id" => user_id, "password" => "pw"})
        {:ok, view, _html} = live(conn, "/dashboard")

        _ =
          view
          |> element("button[phx-click=\"set_order_type\"][phx-value-type=\"sell\"]")
          |> render_click()

        _ =
          view
          |> element("button[phx-click=\"set_input_mode\"][phx-value-mode=\"btc\"]")
          |> render_click()

        _ =
          view
          |> form("form[phx-submit=\"place_order\"]", %{"amount" => "0.1"})
          |> render_submit()

        assert_flash(view, :error, "No tienes suficientes activos")
      after
        :meck.unload(Directorio)
      end
    end

    test "place_order generic error shows flash" do
      user_id = "dash_evt_#{System.unique_integer([:positive])}"
      creds = %{"password" => "pw"}
      :ok = Directorio.register(user_id, creds)
      {:ok, _pid} = Directorio.login(user_id, creds)

      :ok = :meck.new(Directorio, [:passthrough])
      :meck.expect(Directorio, :buy, fn ^user_id, "BTC", _qty -> {:error, :boom} end)

      try do
        conn = session_conn(%{"user_id" => user_id, "password" => "pw"})
        {:ok, view, _html} = live(conn, "/dashboard")

        _ =
          view |> form("form[phx-submit=\"place_order\"]", %{"amount" => "1"}) |> render_submit()

        assert_flash(view, :error, "Error:")
      after
        :meck.unload(Directorio)
      end
    end

    test "set_input_mode clears quantity" do
      user_id = "dash_evt_#{System.unique_integer([:positive])}"
      creds = %{"password" => "pw"}
      :ok = Directorio.register(user_id, creds)
      {:ok, _pid} = Directorio.login(user_id, creds)

      conn = session_conn(%{"user_id" => user_id, "password" => "pw"})
      {:ok, view, _html} = live(conn, "/dashboard")

      html =
        view
        |> element("button[phx-click=\"set_input_mode\"][phx-value-mode=\"btc\"]")
        |> render_click()

      assert html =~ "name=\"amount\""
    end

    test "handle_info ignores non-BTC ticks" do
      user_id = "dash_info_#{System.unique_integer([:positive])}"
      creds = %{"password" => "pw"}
      :ok = Directorio.register(user_id, creds)
      {:ok, _pid} = Directorio.login(user_id, creds)

      conn = session_conn(%{"user_id" => user_id, "password" => "pw"})
      {:ok, view, _html} = live(conn, "/dashboard")

      state_before = :sys.get_state(view.pid)
      assert is_number(state_before.socket.assigns.current_price)

      send(view.pid, {:price_tick, "ETH", 999.0})
      _ = render(view)

      state_after = :sys.get_state(view.pid)
      assert state_after.socket.assigns.current_price == state_before.socket.assigns.current_price
    end

    test "handle_info alert adds notification and dismiss removes it" do
      user_id = "dash_alert_#{System.unique_integer([:positive])}"
      creds = %{"password" => "pw"}
      :ok = Directorio.register(user_id, creds)
      {:ok, _pid} = Directorio.login(user_id, creds)

      conn = session_conn(%{"user_id" => user_id, "password" => "pw"})
      {:ok, view, _html} = live(conn, "/dashboard")

      send(view.pid, {:alert, %{asset: "BTC", current_price: 123.45, change: 0.10}})
      html = render(view)
      assert html =~ "BTC subió"

      state = :sys.get_state(view.pid)
      [first | _] = state.socket.assigns.notifications
      assert is_integer(first.id)

      send(view.pid, {:dismiss_notification, first.id})
      _ = render(view)

      state2 = :sys.get_state(view.pid)
      assert Enum.all?(state2.socket.assigns.notifications, &(&1.id != first.id))
    end

    test "toggle_history toggles the assigns" do
      user_id = "dash_toggle_#{System.unique_integer([:positive])}"
      creds = %{"password" => "pw"}
      :ok = Directorio.register(user_id, creds)
      {:ok, _pid} = Directorio.login(user_id, creds)

      conn = session_conn(%{"user_id" => user_id, "password" => "pw"})
      {:ok, view, _html} = live(conn, "/dashboard")

      assert :sys.get_state(view.pid).socket.assigns.show_history == false

      _ = view |> element("button[phx-click=\"toggle_history\"]") |> render_click()
      assert :sys.get_state(view.pid).socket.assigns.show_history == true

      _ = view |> element("button[phx-click=\"toggle_history\"]") |> render_click()
      assert :sys.get_state(view.pid).socket.assigns.show_history == false
    end

    test "logout event triggers redirect" do
      user_id = "dash_logout_#{System.unique_integer([:positive])}"
      creds = %{"password" => "pw"}
      :ok = Directorio.register(user_id, creds)
      {:ok, _pid} = Directorio.login(user_id, creds)

      conn = session_conn(%{"user_id" => user_id, "password" => "pw"})
      {:ok, view, _html} = live(conn, "/dashboard")

      assert {:error, {:redirect, %{to: "/session/logout"}}} =
               view |> element("button[phx-click=\"logout\"]") |> render_click()
    end
  end
end
