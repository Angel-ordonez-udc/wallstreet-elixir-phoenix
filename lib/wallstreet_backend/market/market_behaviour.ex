defmodule WallstreetBackend.Market.MarketBehaviour do
  @moduledoc """
  Behaviour for the market service.
  """

  @doc "Returns the current price of an asset."
  @callback current_price(asset :: String.t()) :: {:ok, float()} | {:error, term()}

  @doc "Subscribes the current process to price updates."
  @callback subscribe() :: :ok

  @doc "Returns the list of available assets."
  @callback list_assets() :: [String.t()]
end
