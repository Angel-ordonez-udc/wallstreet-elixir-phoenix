defmodule WallstreetBackend.Notifications.NotificationsBehaviour do
  @moduledoc """
  Behaviour for the notifications service.
  Subscribes a user to price alerts for an asset: if the current price varies
  more than 5% from the purchase price, the alert is triggered.
  """

  @doc "Subscribes a user to price alerts for an asset and purchase price."
  @callback subscribe_alerts(
              user_id :: String.t(),
              asset :: String.t(),
              purchase_price :: float()
            ) ::
              :ok | {:error, term()}

  @doc "Unsubscribes a user from alerts."
  @callback unsubscribe_alerts(user_id :: String.t()) :: :ok

  @doc "Lists the active alerts for a user."
  @callback list_alerts(user_id :: String.t()) :: [map()]
end
