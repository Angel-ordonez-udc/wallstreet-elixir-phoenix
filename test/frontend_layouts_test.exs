defmodule WallstreetFrontend.LayoutsTest do
  use ExUnit.Case, async: true

  alias WallstreetFrontend.Layouts

  defp html_of(component) do
    component
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  test "root/1 renders HTML shell and includes inner content" do
    html =
      Layouts.root(%{inner_content: "<div id=\"inner\">ok</div>"})
      |> html_of()

    assert html =~ "<!DOCTYPE html>"
    assert html =~ "<html"
    assert html =~ "csrf-token"
    assert html =~ "Wall Street"

    # inner_content is interpolated as text and therefore HTML-escaped
    assert html =~ "id=&quot;inner&quot;"
    assert html =~ "&gt;ok&lt;"
  end

  test "app/1 renders flash group and inner content" do
    html =
      Layouts.app(%{flash: %{}, inner_content: "<p>hello</p>"})
      |> html_of()

    assert html =~ "<main>"
    assert html =~ "hello"
  end

  test "app/1 shows info and error flashes" do
    # Phoenix.Flash.get/2 typically expects string keys.
    flash = %{"info" => "info msg", "error" => "error msg"}

    html =
      Layouts.app(%{flash: flash, inner_content: ""})
      |> html_of()

    assert html =~ "info msg"
    assert html =~ "error msg"
  end
end
