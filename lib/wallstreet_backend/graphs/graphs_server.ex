defmodule WallstreetBackend.Graphs.GraphsServer do
  @moduledoc """
  Builds its own time series from market ticks.
  Stores each received tick with its reception timestamp.
  """

  use GenServer

  @behaviour WallstreetBackend.ServiceBehaviour
  @behaviour WallstreetBackend.Graphs.GraphsBehaviour

  @graf_ets :grafica
  @tick_topic "market:prices"

  # ----------------- CLIENT API ----------------------

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def historic(start_date, end_date) do
    GenServer.call(__MODULE__, {:historic, start_date, end_date})
  end

  @impl true
  def ohlc(start_date, end_date, interval) do
    GenServer.call(__MODULE__, {:ohlc, start_date, end_date, interval})
  end

  @impl true
  def status, do: GenServer.call(__MODULE__, :status)

  @impl true
  def service_name, do: "GraphsServer"

  # ---------------- SERVER INIT ----------------------

  @impl true
  def init(_opts) do
    :ets.new(@graf_ets, [:named_table, :public, :bag, read_concurrency: true])

    Phoenix.PubSub.subscribe(WallstreetBackend.PubSub, @tick_topic)

    {:ok, %{}}
  end

  # ---------------- RECEIVE TICKS ----------------------

  @impl true
  def handle_info({:price_tick, asset, price}, state) do
    received_ts = DateTime.utc_now()

    # Store each tick WITHOUT overwriting
    :ets.insert(@graf_ets, {asset, received_ts, price})

    {:noreply, state}
  end

  # ---------------- HISTORIC ----------------------

  @impl true
  def handle_call({:historic, start_date, end_date}, _from, state) do
    start_ts = start_date
    end_ts = end_date

    data =
      :ets.tab2list(@graf_ets)
      |> Enum.filter(fn {_asset, ts, _price} ->
        ts >= start_ts and ts <= end_ts
      end)
      |> Enum.sort_by(fn {_asset, ts, _} -> ts end)
      |> Enum.map(fn {_asset, ts, price} ->
        {ts, price}
      end)

    {:reply, {:ok, data}, state}
  end

  # ---------------- OHLC ----------------------

  @impl true
  def handle_call({:ohlc, start_date, end_date, interval}, _from, state) do
    seconds = interval_to_seconds(interval)

    start_ts = start_date
    end_ts = end_date

    data =
      :ets.tab2list(@graf_ets)
      |> Enum.filter(fn {_asset, ts, _price} ->
        ts >= start_ts and ts <= end_ts
      end)
      |> Enum.sort_by(fn {_asset, ts, _} -> ts end)
      |> Enum.group_by(fn {_asset, ts, _} ->
        bucket(ts, seconds)
      end)
      |> Enum.map(fn {bucket_ts, entries} ->
        prices = Enum.map(entries, fn {_a, _t, p} -> p end)

        %{
          timestamp: bucket_ts,
          open: List.first(prices),
          high: Enum.max(prices),
          low: Enum.min(prices),
          close: List.last(prices)
        }
      end)
      |> Enum.sort_by(& &1.timestamp)

    {:reply, {:ok, data}, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, :ok, state}
  end

  # ---------------- HELPERS ----------------------

  defp interval_to_seconds("1m"), do: 60
  defp interval_to_seconds("5m"), do: 300
  defp interval_to_seconds("1h"), do: 3600
  defp interval_to_seconds(_), do: 60

  defp bucket(%DateTime{} = dt, seconds) do
    ts = DateTime.to_unix(dt)
    div(ts, seconds) * seconds
  end
end
