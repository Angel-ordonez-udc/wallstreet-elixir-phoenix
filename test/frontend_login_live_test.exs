defmodule WallstreetFrontend.LoginLiveTest do
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest
  import Phoenix.ConnTest
  import Plug.Conn

  @endpoint WallstreetFrontend.Endpoint

  defp session_conn(session \\ %{}) do
    conn =
      build_conn()
      |> Map.put(:secret_key_base, String.duplicate("a", 64))
      |> Plug.Session.call(Plug.Session.init(store: :cookie, key: "_test", signing_salt: "salt"))
      |> fetch_session()

    Enum.reduce(session, conn, fn {k, v}, acc -> put_session(acc, k, v) end)
  end

  describe "mount/3" do
    test "without session stays on /login and shows form" do
      {:ok, _lv, html} = live(session_conn(), "/login")
      assert html =~ "Wall Street"
      assert html =~ "Usuario"
      assert html =~ "Contrasena"
    end

    test "with session navigates to /dashboard" do
      conn = session_conn(%{"user_id" => "lv_login_1", "password" => "pw"})

      assert {:error, {:live_redirect, %{to: "/dashboard"}}} = live(conn, "/login")
    end
  end

  describe "toggle_mode" do
    test "toggles between login and register" do
      {:ok, lv, html} = live(session_conn(), "/login")
      assert html =~ "Iniciar Sesion"

      html = lv |> element("button", "Registrarse") |> render_click()
      assert html =~ "Crear cuenta"

      html = lv |> element("button", "Iniciar Sesion") |> render_click()
      assert html =~ "Entrar"
    end
  end
end
