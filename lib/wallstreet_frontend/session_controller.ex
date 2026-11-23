defmodule WallstreetFrontend.SessionController do
  @moduledoc """
  Controller for managing user sessions.
  Stores credentials in the cookie so users do not have to
  log in again when refreshing the page.
  """

  use Phoenix.Controller, formats: [:html]

  alias WallstreetBackend.Directorio

  def login(conn, %{"user_id" => user_id, "password" => password, "mode" => mode}) do
    user_id = String.trim(user_id)
    password = String.trim(password)
    credentials = %{"password" => password}

    result =
      case mode do
        "register" ->
          case Directorio.register(user_id, credentials) do
            :ok -> Directorio.login(user_id, credentials)
            {:error, :user_already_exists} -> {:error, :user_already_exists}
          end

        _ ->
          Directorio.login(user_id, credentials)
      end

    case result do
      {:ok, _pid} ->
        conn
        |> put_session(:user_id, user_id)
        |> put_session(:password, password)
        |> redirect(to: "/dashboard")

      {:error, :user_already_exists} ->
        conn
        |> put_flash(:error, "El usuario ya existe")
        |> redirect(to: "/login")

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, "Credenciales invalidas")
        |> redirect(to: "/login")

      {:error, :user_not_found} ->
        conn
        |> put_flash(:error, "Usuario no encontrado")
        |> redirect(to: "/login")
    end
  end

  def logout(conn, _params) do
    user_id = get_session(conn, :user_id)
    if user_id, do: Directorio.logout(user_id)

    conn
    |> clear_session()
    |> redirect(to: "/login")
  end
end
