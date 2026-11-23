defmodule WallstreetFrontend.ErrorHTMLTest do
  use ExUnit.Case, async: true

  alias WallstreetFrontend.ErrorHTML

  test "render/2 returns status message from template" do
    assert ErrorHTML.render("404.html", %{}) == "Not Found"
    assert ErrorHTML.render("500.html", %{}) == "Internal Server Error"
  end
end
