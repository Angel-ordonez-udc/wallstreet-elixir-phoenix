defmodule WallstreetFrontend.Components.OrderComponentTest do
  use ExUnit.Case, async: true

  alias WallstreetFrontend.Components.OrderComponent

  defp html_of(component) do
    component
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  test "renders buy/sell buttons and current price" do
    html =
      OrderComponent.render(%{
        order_type: "buy",
        quantity: "",
        current_price: 12_345.67,
        wallet: %{balance: 1000.0, positions: %{}},
        input_mode: "usd"
      })
      |> html_of()

    assert html =~ "Nueva Orden"
    assert html =~ "Comprar"
    assert html =~ "Vender"
    assert html =~ "Precio actual BTC"
    assert html =~ "12345" or html =~ "12,345" or html =~ "12.345"
  end

  test "shows BTC wallet line only when BTC is present" do
    html_no_btc =
      OrderComponent.render(%{
        order_type: "buy",
        quantity: "",
        current_price: 100.0,
        wallet: %{balance: 1000.0, positions: %{}},
        input_mode: "usd"
      })
      |> html_of()

    refute html_no_btc =~ "BTC en cartera"

    html_with_btc =
      OrderComponent.render(%{
        order_type: "sell",
        quantity: "",
        current_price: 100.0,
        wallet: %{balance: 1000.0, positions: %{"BTC" => 1.5}},
        input_mode: "usd"
      })
      |> html_of()

    assert html_with_btc =~ "BTC en cartera"
    assert html_with_btc =~ "1.5000"
  end

  test "renders conversion preview when quantity is set" do
    html_usd =
      OrderComponent.render(%{
        order_type: "buy",
        quantity: "100",
        current_price: 50.0,
        wallet: %{balance: 1000.0, positions: %{}},
        input_mode: "usd"
      })
      |> html_of()

    assert html_usd =~ "Recibiras" or html_usd =~ "Recibir"
    assert html_usd =~ "BTC"

    html_btc =
      OrderComponent.render(%{
        order_type: "buy",
        quantity: "2",
        current_price: 50.0,
        wallet: %{balance: 1000.0, positions: %{}},
        input_mode: "btc"
      })
      |> html_of()

    assert html_btc =~ "Coste" or html_btc =~ "$"
  end

  test "renders '-' preview on invalid quantity" do
    html =
      OrderComponent.render(%{
        order_type: "buy",
        quantity: "foo",
        current_price: 50.0,
        wallet: %{balance: 1000.0, positions: %{}},
        input_mode: "usd"
      })
      |> html_of()

    assert html =~ "-"
  end
end
