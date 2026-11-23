defmodule WallstreetFrontend.Components.GraphComponent do
  @moduledoc """
  Real-time price chart component.
  Draws an SVG showing BTC/USD price evolution over the last minute.
  """

  use Phoenix.Component

  def render(assigns) do
    prices = assigns.price_history |> Enum.reverse()
    {svg_path, min_p, max_p} = build_svg_path(prices)

    assigns =
      assign(assigns, svg_path: svg_path, min_p: min_p, max_p: max_p, point_count: length(prices))

    ~H"""
    <div style="background:#141926;border:1px solid #1e293b;border-radius:12px;padding:1.25rem;">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:1rem;">
        <div>
          <h3 style="font-size:0.95rem;font-weight:600;color:#e2e8f0;">BTC/USD</h3>
          <p style="font-size:0.75rem;color:#64748b;">Precio en tiempo real (ultimo minuto)</p>
        </div>
        <div style="text-align:right;">
          <span style={"font-size:1.5rem;font-weight:700;" <>
            if(@current_price >= @previous_price, do: "color:#34d399;", else: "color:#f87171;")}>
            ${format_price(@current_price)}
          </span>
        </div>
      </div>

      <div style="position:relative;height:320px;background:#0f1320;border-radius:8px;overflow:hidden;">
        <svg viewBox="0 0 600 320" preserveAspectRatio="none" style="width:100%;height:100%;">
          <line x1="0" y1="80" x2="600" y2="80" stroke="#1e293b" stroke-width="0.5" />
          <line x1="0" y1="160" x2="600" y2="160" stroke="#1e293b" stroke-width="0.5" />
          <line x1="0" y1="240" x2="600" y2="240" stroke="#1e293b" stroke-width="0.5" />

          <path
            :if={@point_count > 1}
            d={@svg_path <> " L 600 320 L 0 320 Z"}
            fill={if(@current_price >= @previous_price, do: "url(#greenGrad)", else: "url(#redGrad)")}
          />

          <path
            :if={@point_count > 1}
            d={@svg_path}
            fill="none"
            stroke={if(@current_price >= @previous_price, do: "#34d399", else: "#f87171")}
            stroke-width="2"
          />

          <defs>
            <linearGradient id="greenGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stop-color="#34d399" stop-opacity="0.1" />
              <stop offset="100%" stop-color="#34d399" stop-opacity="0" />
            </linearGradient>
            <linearGradient id="redGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stop-color="#f87171" stop-opacity="0.1" />
              <stop offset="100%" stop-color="#f87171" stop-opacity="0" />
            </linearGradient>
          </defs>
        </svg>

        <div :if={@point_count > 1} style="position:absolute;top:0;right:0;bottom:0;display:flex;flex-direction:column;justify-content:space-between;padding:0.25rem 0.5rem;">
          <span style="font-size:0.65rem;color:#475569;">${format_price(@max_p)}</span>
          <span style="font-size:0.65rem;color:#475569;">${format_price(@min_p)}</span>
        </div>
      </div>
    </div>
    """
  end

  defp build_svg_path([]), do: {"M 0 160", 0, 0}
  defp build_svg_path([single]), do: {"M 0 160 L 600 160", single, single}

  defp build_svg_path(prices) do
    avg = Enum.sum(prices) / length(prices)
    padded_range = avg * 0.04
    display_min = avg - padded_range / 2
    display_max = avg + padded_range / 2

    count = length(prices)
    step = 600 / max(count - 1, 1)

    points =
      prices
      |> Enum.with_index()
      |> Enum.map(fn {price, i} ->
        x = round(i * step)
        y_ratio = (price - display_min) / padded_range
        y_clamped = max(0.02, min(0.98, y_ratio))
        y = round(310 - y_clamped * 300)
        "#{x} #{y}"
      end)

    path = "M " <> Enum.join(points, " L ")
    {path, display_min, display_max}
  end

  defp format_price(price) when is_number(price) do
    :erlang.float_to_binary(price / 1, decimals: 2)
  end
end
