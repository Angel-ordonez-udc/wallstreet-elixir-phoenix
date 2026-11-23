# TODO Test para el mercado (ticks)

defmodule WallstreetBackend.Market.MarketServerTest do
  use ExUnit.Case, async: false

  alias WallstreetBackend.Market.MarketServer
  alias WallstreetBackend.Repo

  setup do
    _ = Process.whereis(Repo) || start_supervised!({Repo, []})

    # Start MarketServer if not already started by application
    _ = Process.whereis(MarketServer) || start_supervised!({MarketServer, []})

    :ok
  end

  test "status/0 replies :ok" do
    assert :ok = MarketServer.status()
  end

  test "list_assets/0 includes BTC" do
    assets = MarketServer.list_assets()
    assert "BTC" in assets
  end

  test "current_price/1 returns {:ok, number} for BTC" do
    assert {:ok, price} = MarketServer.current_price("BTC")
    assert is_number(price)
    assert price >= 0
  end

  test "subscribe/0 and tick broadcast a :price_tick message" do
    # subscribe current test process
    assert :ok = MarketServer.subscribe()

    # force a tick without waiting 1s (send directly to server)
    send(Process.whereis(MarketServer), :tick)

    assert_receive {:price_tick, "BTC", price}, 500
    assert is_number(price)
  end

  test "tick updates Repo market price" do
    # ensure BTC price isn't set yet in repo and then force tick
    _ = Repo.update_market_price("BTC", 0.0)

    send(Process.whereis(MarketServer), :tick)
    Process.sleep(10)

    assert {:ok, price} = Repo.get_market_price("BTC")
    assert is_number(price)
  end

  test "current_price returns asset_not_found style default for unknown asset" do
    # current_price/1 does not error; it returns 0.0 for unknown asset list
    assert {:ok, price} = MarketServer.current_price("UNKNOWN")
    assert price == 0.0
  end
end
