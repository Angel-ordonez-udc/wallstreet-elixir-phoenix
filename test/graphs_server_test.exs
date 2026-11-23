defmodule WallstreetBackend.Graphs.GraphsServerTest do
  use ExUnit.Case, async: false

  alias WallstreetBackend.Graphs.GraphsServer

  @asset "BTC"

  setup do
    _pid = Process.whereis(GraphsServer) || start_supervised!({GraphsServer, []})

    # Clear ETS table between runs (if it exists)
    if :ets.whereis(:grafica) != :undefined do
      :ets.delete_all_objects(:grafica)
    end

    :ok
  end

  test "status/0 replies :ok" do
    assert :ok = GraphsServer.status()
  end

  test "historic/2 returns ticks within range sorted by timestamp" do
    now = DateTime.utc_now()

    # Insert deterministic ticks into ETS (avoid relying on PubSub)
    t1 = DateTime.add(now, -10, :second)
    t2 = DateTime.add(now, -5, :second)
    t3 = now

    :ets.insert(:grafica, {@asset, t2, 102.0})
    :ets.insert(:grafica, {@asset, t1, 101.0})
    :ets.insert(:grafica, {@asset, t3, 103.0})

    start_dt = DateTime.add(now, -11, :second)
    end_dt = DateTime.add(now, 1, :second)

    assert {:ok, data} = GraphsServer.historic(start_dt, end_dt)
    assert Enum.map(data, fn {ts, _p} -> ts end) == Enum.sort([t1, t2, t3])
    assert Enum.map(data, fn {_ts, p} -> p end) == [101.0, 102.0, 103.0]
  end

  test "historic/2 excludes ticks outside the range" do
    now = DateTime.utc_now()

    inside = DateTime.add(now, -3, :second)
    outside = DateTime.add(now, -30, :second)

    :ets.insert(:grafica, {@asset, inside, 200.0})
    :ets.insert(:grafica, {@asset, outside, 50.0})

    assert {:ok, data} = GraphsServer.historic(DateTime.add(now, -5, :second), now)
    assert data == [{inside, 200.0}]
  end

  test "ohlc/3 groups into buckets and computes open/high/low/close" do
    # Anchor timestamps inside a single minute bucket to avoid crossing a minute boundary.
    base = DateTime.utc_now() |> DateTime.truncate(:second)
    minute_start = base |> DateTime.to_unix() |> div(60) |> Kernel.*(60)
    mid_minute = DateTime.from_unix!(minute_start + 30)

    t1 = DateTime.add(mid_minute, 1, :second)
    t2 = DateTime.add(mid_minute, 2, :second)
    t3 = DateTime.add(mid_minute, 3, :second)

    :ets.insert(:grafica, {@asset, t1, 10.0})
    :ets.insert(:grafica, {@asset, t2, 12.0})
    :ets.insert(:grafica, {@asset, t3, 11.0})

    assert {:ok, [bar]} =
             GraphsServer.ohlc(
               DateTime.add(mid_minute, -5, :second),
               DateTime.add(mid_minute, 5, :second),
               "1m"
             )

    assert bar.open == 10.0
    assert bar.high == 12.0
    assert bar.low == 10.0
    assert bar.close == 11.0
    assert is_integer(bar.timestamp)
  end

  test "ohlc/3 supports unknown interval falling back to 1m" do
    now = DateTime.utc_now()

    t1 = DateTime.add(now, -50, :second)
    t2 = DateTime.add(now, -40, :second)

    :ets.insert(:grafica, {@asset, t1, 1.0})
    :ets.insert(:grafica, {@asset, t2, 2.0})

    assert {:ok, bars} = GraphsServer.ohlc(DateTime.add(now, -60, :second), now, "weird")
    assert length(bars) >= 1
  end

  test "handle_info stores ticks when receiving pubsub price_tick" do
    now = DateTime.utc_now()
    before_count = :ets.info(:grafica, :size) || 0

    send(Process.whereis(GraphsServer), {:price_tick, @asset, 999.0})

    # allow the message to be processed
    Process.sleep(10)

    after_count = :ets.info(:grafica, :size)
    assert after_count == before_count + 1

    # sanity check: there is at least one entry for BTC and price 999.0
    assert Enum.any?(:ets.tab2list(:grafica), fn {asset, ts, price} ->
             asset == @asset and price == 999.0 and ts > DateTime.add(now, -5, :second)
           end)
  end
end
