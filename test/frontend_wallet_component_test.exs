defmodule WallstreetFrontend.Components.WalletComponentTest do
  use ExUnit.Case, async: true

  alias WallstreetFrontend.Components.WalletComponent

  defp html_of(component) do
    component
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  test "renders empty positions state" do
    html =
      WalletComponent.render(%{wallet: %{balance: 10_000.0, positions: %{}}, current_price: 100.0})
      |> html_of()

    assert html =~ "Cartera"
    assert html =~ "Saldo disponible"
    assert html =~ "Sin posiciones abiertas"
    assert html =~ "$10000.00"
  end

  test "renders positions and total value" do
    html =
      WalletComponent.render(%{
        wallet: %{balance: 100.0, positions: %{"BTC" => 2.0}},
        current_price: 10.0
      })
      |> html_of()

    assert html =~ "BTC"
    assert html =~ "2.0000"
    assert html =~ "$20.00"

    # total = 100 + 2*10
    assert html =~ "$120.00"
  end
end
