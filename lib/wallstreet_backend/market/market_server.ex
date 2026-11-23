defmodule WallstreetBackend.Market.MarketServer do
  @moduledoc """
  Manages the market index. Reads data from ETS for minimal latency.
  Emits price ticks every `:tick_interval` ms via `Process.send_after`.
  """

  use GenServer
  require Logger

  @behaviour WallstreetBackend.ServiceBehaviour
  @behaviour WallstreetBackend.Market.MarketBehaviour

  @tick_interval 1_000
  @ets_table :precios

  # ----------------- CLIENT API ----------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl WallstreetBackend.Market.MarketBehaviour
  def current_price(asset) do
    GenServer.call(__MODULE__, {:current_price, asset})
  end

  @impl WallstreetBackend.Market.MarketBehaviour
  def subscribe do
    Phoenix.PubSub.subscribe(WallstreetBackend.PubSub, "market:prices")
  end

  @impl WallstreetBackend.Market.MarketBehaviour
  def list_assets do
    GenServer.call(__MODULE__, :list_assets)
  end

  @impl WallstreetBackend.ServiceBehaviour
  def status, do: GenServer.call(__MODULE__, :status)

  @impl WallstreetBackend.ServiceBehaviour
  def service_name, do: "MarketServer"
  # ---------------------------------------------------

  # -------------- SERVER CALLBACKS -------------------

  @impl GenServer
  def init(_opts) do
    WallstreetBackend.Market.DataLoader.load!()

    prices =
      :ets.tab2list(@ets_table)
      # Assuming only BTC
      |> Enum.group_by(fn {_ts, _price} -> "BTC" end, fn {_ts, price} -> price end)

    state = %{
      # %{ "BTC" => [price1, price2, ...] }
      prices: prices,
      current_index: 0,
      asset: "BTC"
    }

    schedule_tick()
    {:ok, state}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end

  @impl GenServer
  def handle_info(:tick, state) do
    prices = Map.get(state, :prices)[state.asset] || []
    next_index = rem(state.current_index + 1, length(prices))
    current_price = Enum.at(prices, next_index, 0.0)

    # Update centralized repository
    WallstreetBackend.Repo.update_market_price(state.asset, current_price)

    # Publish price via PubSub
    Phoenix.PubSub.broadcast(
      WallstreetBackend.PubSub,
      "market:prices",
      {:price_tick, state.asset, current_price}
    )

    schedule_tick()
    {:noreply, %{state | current_index: next_index}}
  end

  @impl GenServer
  def handle_call({:current_price, asset}, _from, state) do
    prices = Map.get(state.prices, asset, [])
    price = Enum.at(prices, state.current_index, 0.0)
    {:reply, {:ok, price}, state}
  end

  @impl GenServer
  def handle_call(:list_assets, _from, state) do
    {:reply, Map.keys(state.prices), state}
  end

  @impl GenServer
  def handle_call(:status, _from, state) do
    {:reply, :ok, state}
  end

  # ---------------------------------------------------
end
