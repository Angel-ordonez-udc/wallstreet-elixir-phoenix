defmodule WallstreetBackend.ServiceBehaviour do
  @moduledoc """
  Common behaviour for all system services.

  Each service (Market, Operations, Graphs, Notifications)
  implements these callbacks so that `HealthChecker` can
  monitor them uniformly.
  """

  @doc "Returns the health status of the service."
  @callback status() :: :ok | {:error, term()}

  @doc "Returns the human-readable name of the service."
  @callback service_name() :: String.t()
end
