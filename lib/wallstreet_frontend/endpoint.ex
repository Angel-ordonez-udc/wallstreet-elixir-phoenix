defmodule WallstreetFrontend.Endpoint do
  @moduledoc """
  HTTP and WebSocket entry point. Configures security plugs, routes, and the LiveView socket.
  """

  use Phoenix.Endpoint, otp_app: :wallstreet

  @session_options [
    store: :cookie,
    key: "_wallstreet_key",
    signing_salt: "wallstreet_salt",
    same_site: "Lax"
  ]

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  plug(Plug.Static,
    at: "/assets/phoenix",
    from: {:phoenix, "priv/static"},
    gzip: false
  )

  plug(Plug.Static,
    at: "/assets/phoenix_live_view",
    from: {:phoenix_live_view, "priv/static"},
    gzip: false
  )

  plug(Plug.Static,
    at: "/",
    from: {:wallstreet, "priv/static"},
    gzip: false
  )

  plug(Plug.RequestId)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(WallstreetFrontend.Router)
end
