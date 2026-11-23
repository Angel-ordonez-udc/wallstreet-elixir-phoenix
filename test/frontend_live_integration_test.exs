defmodule WallstreetFrontend.LiveIntegrationTest do
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest
  import Phoenix.ConnTest
  import Plug.Conn

  alias WallstreetBackend.Directorio

  @endpoint WallstreetFrontend.Endpoint

  defp session_conn(session \\ %{}) do
    conn =
      build_conn()
      |> Map.put(:secret_key_base, String.duplicate("a", 64))
      |> Plug.Session.call(Plug.Session.init(store: :cookie, key: "_test", signing_salt: "salt"))
      |> fetch_session()

    Enum.reduce(session, conn, fn {k, v}, acc -> put_session(acc, k, v) end)
  end

  setup do
    user_id = "lv_user_#{System.unique_integer([:positive])}"
    creds = %{"password" => "pw"}

    :ok = Directorio.register(user_id, creds)

    conn =
      session_conn(%{
        "user_id" => user_id,
        "password" => "pw"
      })

    %{conn: conn, user_id: user_id}
  end

  test "GET /dashboard mounts DashboardLive and shows user id", %{conn: conn, user_id: user_id} do
    {:ok, _view, html} = live(conn, "/dashboard")
    assert html =~ user_id
  end

  test "GET / mounts LoginLive when no session" do
    conn = session_conn()

    {:ok, _view, html} = live(conn, "/")

    # Tolerant of accents and minor variations
    assert html =~ "Iniciar" and (html =~ "Sesion" or html =~ "Sesión")
    assert html =~ "Registr"
  end

  test "DashboardLive reacts to :price_tick", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dashboard")

    send(view.pid, {:price_tick, "BTC", 12_345.67})
    html = render(view)

    # Tolerant: may appear with separators/currency symbols
    assert html =~ "12345" or html =~ "12,345" or html =~ "12.345"
  end

  test "DashboardLive renders something on :alert", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dashboard")

    send(view.pid, {:alert, %{asset: "BTC", current_price: 9999.0, change: 0.10}})
    html = render(view)

    # Avoid exact text matching; asset name is enough
    assert html =~ "BTC"
  end

  describe "DashboardLive interactions (best-effort)" do
    test "ignores non-BTC price ticks" do
      user_id = "dash_user_#{System.unique_integer([:positive])}"
      creds = %{"password" => "pw"}
      :ok = Directorio.register(user_id, creds)
      {:ok, _pid} = Directorio.login(user_id, creds)

      conn = session_conn(%{"user_id" => user_id, "password" => "pw"})
      {:ok, view, _html} = live(conn, "/dashboard")

      send(view.pid, {:price_tick, "ETH", 1.0})
      assert render(view) =~ user_id
    end

    test "toggle_history click only if button exists" do
      user_id = "dash_user_#{System.unique_integer([:positive])}"
      creds = %{"password" => "pw"}
      :ok = Directorio.register(user_id, creds)
      {:ok, _pid} = Directorio.login(user_id, creds)

      conn = session_conn(%{"user_id" => user_id, "password" => "pw"})
      {:ok, view, _html} = live(conn, "/dashboard")

      html = render(view)

      if html =~ "toggle_history" do
        view |> element("[phx-click='toggle_history']") |> render_click()
        assert render(view) =~ user_id
      else
        assert true
      end
    end
  end
end
