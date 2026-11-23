defmodule WallstreetBackend.DirectorioTest do
  use ExUnit.Case, async: true

  alias WallstreetBackend.Directorio

  test "Directorio delegates basic calls" do
    # These are shallow delegation tests: they exist mainly to bump coverage
    # and catch accidental API regressions.

    assert :ok = Directorio.subscribe_market_updates()

    user_id = "dir_user_#{System.unique_integer([:positive])}"
    assert :ok = Directorio.subscribe_user_alerts(user_id)

    # Current price comes from the MarketServer stubbed data loader.
    assert {:ok, price} = Directorio.current_price("BTC")
    assert is_number(price)

    # NOTIFICATIONS delegates
    user_id2 = "dir_notif_#{System.unique_integer([:positive])}"
    assert :ok = Directorio.unsubscribe_alerts(user_id2)
    assert :ok = Directorio.subscribe_alerts(user_id2, "BTC", 100.0)

    # GRAPHS delegates (smoke)
    {:ok, now} = DateTime.now("Etc/UTC")
    start_dt = DateTime.add(now, -60, :second)

    assert {:ok, _ticks} = Directorio.historic(start_dt, now)
    assert {:ok, _ohlc} = Directorio.ohlc(start_dt, now, "1m")

    # OPERATIONS delegates need a real user
    user_id3 = "dir_ops_#{System.unique_integer([:positive])}"
    creds = %{"password" => "pw"}
    :ok = Directorio.register(user_id3, creds)
    {:ok, _pid} = Directorio.login(user_id3, creds)

    # MarketServer.list_assets/0 returns a plain list.
    assets = WallstreetBackend.Market.MarketServer.list_assets()

    # In some fixtures only BTC exists; buying BTC may be unsupported in Operations.
    # So: always cover transaction_history/1, and only attempt a buy if there's a non-BTC asset.
    case Enum.find(assets, &(&1 != "BTC")) do
      nil ->
        assert {:ok, _price} = Directorio.current_price("BTC")

      asset ->
        assert {:ok, _tx} = Directorio.buy(user_id3, asset, 1)
    end

    assert {:ok, list} = Directorio.transaction_history(user_id3)
    assert is_list(list)

    _ = Directorio.logout(user_id3)
  end
end
