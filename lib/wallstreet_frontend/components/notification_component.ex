defmodule WallstreetFrontend.Components.NotificationComponent do
  @moduledoc """
  Price change notification component.
  Displays toasts when BTC price changes more than 0.5%.
  """

  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div style="position:fixed;bottom:1rem;right:1rem;z-index:999;display:flex;flex-direction:column;gap:0.25rem;max-width:600px;">
      <div
        :for={notif <- Enum.take(@notifications, 3)}
        style={"padding:0.3rem 0.6rem;border-radius:4px;font-size:0.65rem;opacity:0.8;" <>
          if(notif.type == "subió", do: "background:#065f46;color:#6ee7b7;", else: "background:#7f1d1d;color:#fca5a5;")}
      >
        {notif.message}
      </div>
    </div>
    """
  end
end
