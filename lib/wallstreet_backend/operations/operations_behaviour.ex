defmodule WallstreetBackend.Operations.OperationsBehaviour do
  @moduledoc """
  Behaviour for the operations service.
  """

  @doc "Executes a buy order for a user."
  @callback buy(user_id :: String.t(), asset :: String.t(), quantity :: pos_integer()) ::
              {:ok, map()} | {:error, term()}

  @doc "Executes a sell order for a user."
  @callback sell(user_id :: String.t(), asset :: String.t(), quantity :: pos_integer()) ::
              {:ok, map()} | {:error, term()}

  @doc "Returns the transaction history for a user."
  @callback transaction_history(user_id :: String.t()) :: {:ok, [map()]} | {:error, term()}
end
