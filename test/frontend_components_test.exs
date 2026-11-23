defmodule WallstreetFrontend.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  @components [
    WallstreetFrontend.Components.GraphComponent,
    WallstreetFrontend.Components.WalletComponent,
    WallstreetFrontend.Components.OrderComponent,
    WallstreetFrontend.Components.NotificationComponent
  ]

  defp assigns_for(mod) do
    cond do
      mod == WallstreetFrontend.Components.GraphComponent ->
        [
          price_history: [1.0, 2.0, 3.5],
          current_price: 3.5,
          previous_price: 3.0
        ]

      mod == WallstreetFrontend.Components.WalletComponent ->
        [
          # WalletComponent expects wallet.balance and wallet.positions
          wallet: %{"BTC" => 0.1, balance: 123.45, positions: %{}},
          balance: 123.45,
          current_price: 100.0
        ]

      mod == WallstreetFrontend.Components.OrderComponent ->
        [
          quantity: "",
          order_type: "buy",
          input_mode: "usd",
          current_price: 100.0,
          wallet: %{balance: 1000.0, positions: %{"BTC" => 0.25}}
        ]

      mod == WallstreetFrontend.Components.NotificationComponent ->
        [
          notifications: [
            %{type: "rose", message: "BTC subió 10%"},
            %{type: "fell", message: "BTC bajó 10%"}
          ]
        ]

      true ->
        []
    end
  end

  test "components export render/1" do
    for mod <- @components do
      assert Code.ensure_loaded?(mod)
      assert function_exported?(mod, :render, 1)
    end
  end

  test "components can be rendered with render_component/2 (best-effort)" do
    for mod <- @components do
      html = render_component(&mod.render/1, assigns_for(mod))
      assert is_binary(html)
      assert byte_size(html) > 0
    end
  end
end
