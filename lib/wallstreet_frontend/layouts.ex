defmodule WallstreetFrontend.Layouts do
  @moduledoc """
  Base HTML layouts for the application.
  root/1 is the outer wrapper (head, body, CSS, JS).
  """

  use Phoenix.Component

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="es">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Phoenix.Controller.get_csrf_token()} />
        <title>Wall Street</title>
        <script src="/assets/phoenix/phoenix.min.js"></script>
        <script src="/assets/phoenix_live_view/phoenix_live_view.min.js"></script>
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: #0a0e17;
            color: #e2e8f0;
            min-height: 100vh;
          }
          a { color: #60a5fa; text-decoration: none; }
          a:hover { text-decoration: underline; }
          input:focus { border-color: #2563eb !important; outline: none; }
          button:hover { opacity: 0.9; }
          @media (max-width: 768px) {
            .dashboard-grid { grid-template-columns: 1fr !important; }
          }
        </style>
      </head>
      <body>
        {@inner_content}

        <script>
          document.addEventListener("DOMContentLoaded", function() {
            var csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
            var liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket, {
              params: {_csrf_token: csrfToken}
            });
            liveSocket.connect();
            window.liveSocket = liveSocket;
          });
        </script>
      </body>
    </html>
    """
  end

  def app(assigns) do
    ~H"""
    <main>
      <.flash_group flash={@flash} />
      {@inner_content}
    </main>
    """
  end

  defp flash_group(assigns) do
    ~H"""
    <div style="position:fixed;top:1rem;right:1rem;z-index:1000;display:flex;flex-direction:column;gap:0.5rem;">
      <p :if={Phoenix.Flash.get(@flash, :info)}
         style="background:#065f46;color:#6ee7b7;padding:0.75rem 1.25rem;border-radius:8px;font-size:0.875rem;">
        {Phoenix.Flash.get(@flash, :info)}
      </p>
      <p :if={Phoenix.Flash.get(@flash, :error)}
         style="background:#7f1d1d;color:#fca5a5;padding:0.75rem 1.25rem;border-radius:8px;font-size:0.875rem;">
        {Phoenix.Flash.get(@flash, :error)}
      </p>
    </div>
    """
  end
end
