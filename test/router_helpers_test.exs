defmodule WallstreetFrontend.Router.HelpersTest do
  use ExUnit.Case, async: true

  alias WallstreetFrontend.Router.Helpers, as: Routes

  @endpoint WallstreetFrontend.Endpoint

  test "router helpers generate paths and urls" do
    # Basic path generation
    assert Routes.path(@endpoint, "/") == "/"

    # Known controller routes
    assert Routes.session_path(@endpoint, :login) == "/session/login"
    assert Routes.session_path(@endpoint, :logout) == "/session/logout"

    # LiveView routes
    assert Routes.live_path(@endpoint, WallstreetFrontend.LoginLive, %{}) in ["/", "/login"]
    assert Routes.live_path(@endpoint, WallstreetFrontend.DashboardLive, %{}) == "/dashboard"

    # URL helpers should return a URL (host depends on endpoint config)
    assert Routes.url(@endpoint) =~ "http"

    assert Routes.static_path(@endpoint, "/assets/phoenix/phoenix.min.js") =~
             "/assets/phoenix/phoenix.min.js"
  end
end
