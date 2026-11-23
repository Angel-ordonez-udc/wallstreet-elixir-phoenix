defmodule WallstreetBackend.Users.UserBehaviour do
  @moduledoc """
  Behavior for user service.
  """

  @doc "Authenticate a user with their credentials"
  @callback authenticate(user_id :: String.t(), credentials :: map()) ::
              {:ok, map()} | {:error, :invalid_credentials}

  @doc "Return a user's wallet"
  @callback get_wallet(user_id :: String.t()) :: {:ok, map()} | {:error, term()}
end
