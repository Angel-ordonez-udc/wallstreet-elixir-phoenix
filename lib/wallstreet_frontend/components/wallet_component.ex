defmodule WallstreetFrontend.Components.WalletComponent do
  @moduledoc """
  User wallet component.
  Displays available balance, open positions, and total value.
  """

  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div style="background:#141926;border:1px solid #1e293b;border-radius:12px;padding:1.25rem;">
      <h3 style="font-size:0.95rem;font-weight:600;color:#e2e8f0;margin-bottom:1rem;">Cartera</h3>

      <div style="display:flex;justify-content:space-between;align-items:center;padding:0.75rem;background:#0f1320;border-radius:8px;margin-bottom:1rem;">
        <span style="font-size:0.8rem;color:#94a3b8;">Saldo disponible</span>
        <span style="font-size:1.1rem;font-weight:700;color:#f0f4f8;">
          ${format_price(@wallet.balance)}
        </span>
      </div>

      <div :if={@wallet.positions != %{}} style="display:flex;flex-direction:column;gap:0.5rem;">
        <div
          :for={{asset, quantity} <- @wallet.positions}
          style="display:flex;justify-content:space-between;align-items:center;padding:0.75rem;background:#0f1320;border-radius:8px;"
        >
          <div>
            <span style="font-size:0.9rem;font-weight:600;color:#e2e8f0;">{asset}</span>
            <span style="font-size:0.8rem;color:#64748b;margin-left:0.5rem;">{format_quantity(quantity)} unidades</span>
          </div>
          <div style="text-align:right;">
            <span style="font-size:0.9rem;font-weight:600;color:#e2e8f0;">
              ${format_price(quantity * @current_price)}
            </span>
          </div>
        </div>
      </div>

      <div :if={@wallet.positions == %{}} style="color:#475569;font-size:0.85rem;text-align:center;padding:1.5rem;">
        Sin posiciones abiertas
      </div>

      <div style="margin-top:1rem;padding-top:1rem;border-top:1px solid #1e293b;display:flex;justify-content:space-between;">
        <span style="font-size:0.85rem;color:#94a3b8;">Valor total</span>
        <span style="font-size:1rem;font-weight:700;color:#60a5fa;">
          ${format_price(total_value(@wallet, @current_price))}
        </span>
      </div>
    </div>
    """
  end

  defp total_value(wallet, current_price) do
    positions_value =
      wallet.positions
      |> Enum.map(fn {_asset, qty} -> qty * current_price end)
      |> Enum.sum()

    wallet.balance + positions_value
  end

  defp format_price(price) when is_number(price) do
    :erlang.float_to_binary(price / 1, decimals: 2)
  end

  defp format_quantity(qty) when is_number(qty) do
    :erlang.float_to_binary(qty / 1, decimals: 4)
  end
end
