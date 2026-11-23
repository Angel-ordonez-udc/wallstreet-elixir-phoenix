defmodule WallstreetFrontend.SessionControllerTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Phoenix.ConnTest

  alias WallstreetBackend.Directorio

  @endpoint WallstreetFrontend.Endpoint

  setup do
    user_id = "sess_user_#{System.unique_integer([:positive])}"
    password = "pw"

    %{user_id: user_id, password: password}
  end

  test "register mode stores session and redirects to /dashboard", %{
    user_id: user_id,
    password: password
  } do
    conn = build_conn()

    conn =
      post(conn, "/session/login", %{
        "user_id" => user_id,
        "password" => password,
        "mode" => "register"
      })

    assert redirected_to(conn) == "/dashboard"
    assert get_session(conn, :user_id) == user_id
    assert get_session(conn, :password) == password

    # cleanup (best-effort)
    _ = Directorio.logout(user_id)
  end

  test "login mode with existing user stores session and redirects to /dashboard", %{
    user_id: user_id,
    password: password
  } do
    :ok = Directorio.register(user_id, %{"password" => password})

    conn = build_conn()

    conn =
      post(conn, "/session/login", %{
        "user_id" => user_id,
        "password" => password,
        "mode" => "login"
      })

    assert redirected_to(conn) == "/dashboard"
    assert get_session(conn, :user_id) == user_id
    assert get_session(conn, :password) == password

    _ = Directorio.logout(user_id)
  end

  test "login mode with wrong password redirects to /login and sets flash error", %{
    user_id: user_id,
    password: password
  } do
    :ok = Directorio.register(user_id, %{"password" => password})

    conn = build_conn()

    conn =
      post(conn, "/session/login", %{
        "user_id" => user_id,
        "password" => "wrong",
        "mode" => "login"
      })

    assert redirected_to(conn) == "/login"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Credenciales invalidas"
  end

  test "logout clears session and redirects to /login" do
    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{user_id: "u", password: "pw"})

    conn = get(conn, "/session/logout")

    assert redirected_to(conn) == "/login"
    assert get_session(conn, :user_id) == nil
    assert get_session(conn, :password) == nil
  end

  test "register mode with existing user redirects to /login and sets flash error", %{
    user_id: user_id,
    password: password
  } do
    :ok = :meck.new(Directorio, [:passthrough])

    :meck.expect(Directorio, :register, fn ^user_id, %{"password" => ^password} ->
      {:error, :user_already_exists}
    end)

    try do
      conn = build_conn()

      conn =
        post(conn, "/session/login", %{
          "user_id" => user_id,
          "password" => password,
          "mode" => "register"
        })

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "El usuario ya existe"
    after
      :meck.unload(Directorio)
    end
  end

  test "login mode with missing user redirects to /login and sets flash error", %{
    user_id: user_id,
    password: password
  } do
    :ok = :meck.new(Directorio, [:passthrough])

    :meck.expect(Directorio, :login, fn ^user_id, %{"password" => ^password} ->
      {:error, :user_not_found}
    end)

    try do
      conn = build_conn()

      conn =
        post(conn, "/session/login", %{
          "user_id" => user_id,
          "password" => password,
          "mode" => "login"
        })

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Usuario no encontrado"
    after
      :meck.unload(Directorio)
    end
  end
end
