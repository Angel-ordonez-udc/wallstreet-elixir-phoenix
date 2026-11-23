defmodule WallstreetFrontend.LoginLive do
  @moduledoc """
  Authentication screen. Manages the login/register form
  and redirects to the dashboard if there is an active session.
  """

  use Phoenix.LiveView

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"]
    password = session["password"]

    if user_id && password do
      ensure_user_alive(user_id, password)
      {:ok, push_navigate(socket, to: "/dashboard")}
    else
      {:ok, assign(socket, mode: :login)}
    end
  end

  @impl true
  def handle_event("toggle_mode", _params, socket) do
    new_mode = if socket.assigns.mode == :login, do: :register, else: :login
    {:noreply, assign(socket, mode: new_mode)}
  end

  defp ensure_user_alive(user_id, password) do
    credentials = %{"password" => password}

    case WallstreetBackend.Directorio.login(user_id, credentials) do
      {:ok, _pid} ->
        :ok

      {:error, :user_not_found} ->
        WallstreetBackend.Directorio.register(user_id, credentials)
        WallstreetBackend.Directorio.login(user_id, credentials)

      _ ->
        :ok
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="min-height:100vh;display:flex;align-items:center;justify-content:center;background:linear-gradient(135deg,#0a0e17 0%,#1a1f2e 100%);">
      <div style="width:100%;max-width:420px;padding:2rem;">
        <div style="text-align:center;margin-bottom:2.5rem;">
          <h1 style="font-size:2.5rem;font-weight:800;color:#f0f4f8;letter-spacing:-0.02em;">
            Wall Street
          </h1>
          <p style="color:#94a3b8;margin-top:0.5rem;font-size:0.95rem;">
            Simulador de Trading
          </p>
        </div>

        <div style="background:#141926;border:1px solid #1e293b;border-radius:12px;padding:2rem;">
          <div style="display:flex;margin-bottom:1.5rem;background:#0f1320;border-radius:8px;padding:4px;">
            <button
              phx-click="toggle_mode"
              style={"flex:1;padding:0.6rem;border:none;border-radius:6px;cursor:pointer;font-size:0.875rem;font-weight:600;transition:all 0.2s;" <>
                if(@mode == :login, do: "background:#2563eb;color:white;", else: "background:transparent;color:#64748b;")}
            >
              Iniciar Sesion
            </button>
            <button
              phx-click="toggle_mode"
              style={"flex:1;padding:0.6rem;border:none;border-radius:6px;cursor:pointer;font-size:0.875rem;font-weight:600;transition:all 0.2s;" <>
                if(@mode == :register, do: "background:#2563eb;color:white;", else: "background:transparent;color:#64748b;")}
            >
              Registrarse
            </button>
          </div>

          <form action="/session/login" method="post">
            <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
            <input type="hidden" name="mode" value={if @mode == :register, do: "register", else: "login"} />

            <div style="margin-bottom:1rem;">
              <label style="display:block;font-size:0.8rem;color:#94a3b8;margin-bottom:0.4rem;font-weight:500;">
                Usuario
              </label>
              <input
                type="text"
                name="user_id"
                placeholder="Tu nombre de usuario"
                required
                style="width:100%;padding:0.75rem 1rem;background:#0f1320;border:1px solid #1e293b;border-radius:8px;color:#e2e8f0;font-size:0.95rem;outline:none;"
              />
            </div>

            <div style="margin-bottom:1.5rem;">
              <label style="display:block;font-size:0.8rem;color:#94a3b8;margin-bottom:0.4rem;font-weight:500;">
                Contrasena
              </label>
              <input
                type="password"
                name="password"
                placeholder="Tu contrasena"
                required
                style="width:100%;padding:0.75rem 1rem;background:#0f1320;border:1px solid #1e293b;border-radius:8px;color:#e2e8f0;font-size:0.95rem;outline:none;"
              />
            </div>

            <button
              type="submit"
              style="width:100%;padding:0.75rem;background:#2563eb;color:white;border:none;border-radius:8px;font-size:1rem;font-weight:600;cursor:pointer;"
            >
              {if @mode == :login, do: "Entrar", else: "Crear cuenta"}
            </button>
          </form>
        </div>

        <p style="text-align:center;margin-top:1.5rem;font-size:0.8rem;color:#475569;">
          Saldo inicial: $10,000 USD
        </p>
      </div>
    </div>
    """
  end
end
