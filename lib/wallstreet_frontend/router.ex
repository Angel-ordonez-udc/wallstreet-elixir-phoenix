defmodule WallstreetFrontend.Router do
  @moduledoc """
  Defines all application routes. Groups routes under the :browser pipeline.
  """

  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {WallstreetFrontend.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  scope "/", WallstreetFrontend do
    pipe_through(:browser)

    live("/", LoginLive)
    live("/login", LoginLive)
    live("/dashboard", DashboardLive)

    post("/session/login", SessionController, :login)
    get("/session/logout", SessionController, :logout)
  end
end
