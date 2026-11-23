defmodule WallstreetFrontend.Components.OrderComponent do
  @moduledoc """
  Buy/sell order form component.
  Allows choosing between buying and selling BTC, entering the
  amount in USD or BTC with real-time conversion preview.
  """

  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div style="background:#141926;border:1px solid #1e293b;border-radius:12px;padding:1.25rem;position:sticky;top:1.5rem;">
      <h3 style="font-size:0.95rem;font-weight:600;color:#e2e8f0;margin-bottom:1rem;">Nueva Orden</h3>

      <div style="display:flex;margin-bottom:1.25rem;background:#0f1320;border-radius:8px;padding:4px;">
        <button
          phx-click="set_order_type"
          phx-value-type="buy"
          style={"flex:1;padding:0.6rem;border:none;border-radius:6px;cursor:pointer;font-size:0.85rem;font-weight:600;transition:all 0.2s;" <>
            if(@order_type == "buy", do: "background:#065f46;color:#34d399;", else: "background:transparent;color:#64748b;")}
        >
          Comprar
        </button>
        <button
          phx-click="set_order_type"
          phx-value-type="sell"
          style={"flex:1;padding:0.6rem;border:none;border-radius:6px;cursor:pointer;font-size:0.85rem;font-weight:600;transition:all 0.2s;" <>
            if(@order_type == "sell", do: "background:#7f1d1d;color:#f87171;", else: "background:transparent;color:#64748b;")}
        >
          Vender
        </button>
      </div>

      <div style="margin-bottom:1rem;">
        <label style="display:block;font-size:0.75rem;color:#64748b;margin-bottom:0.3rem;">Precio actual BTC</label>
        <div style="padding:0.75rem;background:#0f1320;border:1px solid #1e293b;border-radius:8px;color:#e2e8f0;font-weight:600;">
          ${format_price(@current_price)}
        </div>
      </div>

      <div style="display:flex;margin-bottom:0.75rem;background:#0f1320;border-radius:6px;padding:3px;">
        <button
          phx-click="set_input_mode"
          phx-value-mode="usd"
          style={"flex:1;padding:0.4rem;border:none;border-radius:4px;cursor:pointer;font-size:0.75rem;font-weight:600;" <>
            if(@input_mode == "usd", do: "background:#1e293b;color:#e2e8f0;", else: "background:transparent;color:#64748b;")}
        >
          USD $
        </button>
        <button
          phx-click="set_input_mode"
          phx-value-mode="btc"
          style={"flex:1;padding:0.4rem;border:none;border-radius:4px;cursor:pointer;font-size:0.75rem;font-weight:600;" <>
            if(@input_mode == "btc", do: "background:#1e293b;color:#e2e8f0;", else: "background:transparent;color:#64748b;")}
        >
          BTC
        </button>
      </div>

      <form phx-submit="place_order">
        <div style="margin-bottom:0.5rem;">
          <label style="display:block;font-size:0.75rem;color:#64748b;margin-bottom:0.3rem;">
            {if @input_mode == "usd", do: "Cantidad en USD", else: "Cantidad en BTC"}
          </label>
          <input
            type="number"
            name="amount"
            value={@quantity}
            step={if @input_mode == "usd", do: "1", else: "0.0001"}
            min="0"
            placeholder={if @input_mode == "usd", do: "100.00", else: "0.0010"}
            style="width:100%;padding:0.75rem;background:#0f1320;border:1px solid #1e293b;border-radius:8px;color:#e2e8f0;font-size:1rem;outline:none;"
          />
          <input type="hidden" name="input_mode" value={@input_mode} />
        </div>

        <div :if={@quantity != "" and @quantity != nil} style="margin-bottom:0.75rem;padding:0.5rem;background:#0f1320;border-radius:6px;">
          <div style="display:flex;justify-content:space-between;">
            <span style="font-size:0.75rem;color:#64748b;">
              {if @input_mode == "usd", do: "Recibiras aprox.", else: "Coste aprox."}
            </span>
            <span style="font-size:0.75rem;color:#94a3b8;">
              {preview_conversion(@quantity, @input_mode, @current_price)}
            </span>
          </div>
        </div>

        <div style="margin-bottom:1rem;padding:0.5rem;background:#0f1320;border-radius:6px;">
          <div style="display:flex;justify-content:space-between;margin-bottom:0.4rem;">
            <span style="font-size:0.75rem;color:#64748b;">Saldo</span>
            <span style="font-size:0.75rem;color:#94a3b8;">${format_price(@wallet.balance)}</span>
          </div>
          <div :if={Map.get(@wallet.positions, "BTC")} style="display:flex;justify-content:space-between;">
            <span style="font-size:0.75rem;color:#64748b;">BTC en cartera</span>
            <span style="font-size:0.75rem;color:#94a3b8;">{format_quantity(Map.get(@wallet.positions, "BTC", 0))}</span>
          </div>
        </div>

        <button
          type="submit"
          style={"width:100%;padding:0.75rem;border:none;border-radius:8px;font-size:0.95rem;font-weight:600;cursor:pointer;" <>
            if(@order_type == "buy", do: "background:#059669;color:white;", else: "background:#dc2626;color:white;")}
        >
          {if @order_type == "buy", do: "Comprar BTC", else: "Vender BTC"}
        </button>
      </form>
    </div>
    """
  end

  defp preview_conversion(qty_str, mode, price) do
    case Float.parse(to_string(qty_str)) do
      {val, _} when val > 0 and price > 0 ->
        if mode == "usd" do
          btc = val / price
          "#{format_quantity(btc)} BTC"
        else
          usd = val * price
          "$#{format_price(usd)}"
        end

      _ ->
        "-"
    end
  end

  defp format_price(price) when is_number(price) do
    :erlang.float_to_binary(price / 1, decimals: 2)
  end

  defp format_quantity(qty) when is_number(qty) do
    :erlang.float_to_binary(qty / 1, decimals: 4)
  end
end
