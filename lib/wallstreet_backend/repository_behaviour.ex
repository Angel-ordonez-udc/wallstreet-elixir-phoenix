defmodule WallstreetBackend.RepositoryBehaviour do
  @moduledoc """
  Unified behaviour for accessing application data.
  """

  alias WallstreetBackend.Schemas.Wallet

  @callback get_wallet(String.t()) :: {:ok, Wallet.t()} | {:error, :user_not_found}
  @callback update_wallet(String.t(), Wallet.t()) :: :ok | {:error, :user_not_found}

  @callback get_market_price(String.t()) :: {:ok, number()} | {:error, :asset_not_found}
  @callback get_market_prices() :: [String.t()]
  @callback update_market_price(String.t(), number()) :: :ok
end
