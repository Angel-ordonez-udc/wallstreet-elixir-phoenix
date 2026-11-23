defmodule WallstreetBackend.Graphs.GraphsBehaviour do
  @moduledoc """
  Behaviour for the graphs service.
  """

  @doc "Retrieves the price history for a date range."
  @callback historic(start_date :: DateTime.t(), end_date :: DateTime.t()) ::
              {:ok, [{DateTime.t(), float()}]} | {:error, term()}

  @doc "Retrieves candlestick (OHLC) data grouped by interval."
  @callback ohlc(start_date :: DateTime.t(), end_date :: DateTime.t(), interval :: String.t()) ::
              {:ok, [map()]} | {:error, term()}
end
