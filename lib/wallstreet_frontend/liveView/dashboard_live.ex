defmodule WallstreetFrontend.DashboardLive do
  @moduledoc """
  Main trader screen. Orchestrates all components:
  chart, wallet, order form, and notifications.

  Subscribes to PubSub to receive real-time price ticks.
  """

  use Phoenix.LiveView

  alias WallstreetBackend.Directorio

  alias WallstreetFrontend.Components.{
    GraphComponent,
    WalletComponent,
    OrderComponent,
    NotificationComponent
  }

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"]
    password = session["password"]

    if is_nil(user_id) do
      {:ok, push_navigate(socket, to: "/login")}
    else
      ensure_user_alive(user_id, password)

      {:ok, price} = Directorio.current_price("BTC")
      wallet_data = load_wallet(user_id)
      {:ok, transactions} = Directorio.transaction_history(user_id)

      if connected?(socket) do
        Directorio.subscribe_market_updates()
        Directorio.subscribe_user_alerts(user_id)
        :ok = Directorio.unsubscribe_alerts(user_id)
        :ok = Directorio.subscribe_alerts(user_id, "BTC", price)
      end

      {:ok,
       assign(socket,
         user_id: user_id,
         current_price: price,
         price_history: [price],
         wallet: wallet_data,
         transactions: Enum.take(transactions, 20),
         quantity: "",
         order_type: "buy",
         input_mode: "usd",
         notifications: [],
         previous_price: price,
         show_history: false
       )}
    end
  end

  @impl true
  def handle_info({:alert, %{asset: asset, current_price: price, change: change}}, socket) do
    direction = if change > 0, do: "subió", else: "bajó"
    msg = "#{asset} #{direction} más de un 5%: $#{format_price(price)}"
    id = System.unique_integer([:positive])
    Process.send_after(self(), {:dismiss_notification, id}, 8_000)

    notifications = [
      %{id: id, message: msg, type: direction} | Enum.take(socket.assigns.notifications, 4)
    ]

    {:noreply, assign(socket, notifications: notifications)}
  end

  def handle_info({:dismiss_notification, id}, socket) do
    notifications = Enum.reject(socket.assigns.notifications, &(&1.id == id))
    {:noreply, assign(socket, notifications: notifications)}
  end

  @impl true
  def handle_info({:price_tick, asset, price}, socket) do
    # Only update if it is the displayed asset (BTC)
    if asset == "BTC" do
      previous_price = socket.assigns.current_price
      price_history = [price | Enum.take(socket.assigns.price_history, 99)]
      wallet = update_wallet_prices(socket.assigns.wallet, price)

      {:noreply,
       assign(socket,
         current_price: price,
         previous_price: previous_price,
         price_history: price_history,
         wallet: wallet
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("place_order", %{"amount" => amount_str, "input_mode" => input_mode}, socket) do
    case Float.parse(amount_str) do
      {amount, _} when amount > 0 ->
        price = socket.assigns.current_price

        btc_quantity =
          if input_mode == "usd" do
            amount / price
          else
            amount
          end

        user_id = socket.assigns.user_id

        result =
          case socket.assigns.order_type do
            "buy" -> Directorio.buy(user_id, "BTC", btc_quantity)
            "sell" -> Directorio.sell(user_id, "BTC", btc_quantity)
          end

        case result do
          {:ok, _tx} ->
            wallet_data = load_wallet(user_id)
            {:ok, transactions} = Directorio.transaction_history(user_id)

            {:noreply,
             socket
             |> assign(
               wallet: wallet_data,
               transactions: Enum.take(transactions, 20),
               quantity: ""
             )
             |> put_flash(:info, "Orden ejecutada correctamente")}

          {:error, :insufficient_funds} ->
            {:noreply, put_flash(socket, :error, "Fondos insuficientes")}

          {:error, :insufficient_assets} ->
            {:noreply, put_flash(socket, :error, "No tienes suficientes activos")}

          {:error, :asset_not_found} ->
            {:noreply, put_flash(socket, :error, "No posees este activo")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Cantidad invalida")}
    end
  end

  def handle_event("set_order_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, order_type: type)}
  end

  def handle_event("set_input_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, input_mode: mode, quantity: "")}
  end

  def handle_event("toggle_history", _params, socket) do
    {:noreply, assign(socket, show_history: !socket.assigns.show_history)}
  end

  def handle_event("logout", _params, socket) do
    {:noreply, redirect(socket, to: "/session/logout")}
  end

  defp ensure_user_alive(user_id, password) do
    credentials = %{"password" => password || ""}

    case Directorio.login(user_id, credentials) do
      {:ok, _pid} ->
        :ok

      {:error, :user_not_found} ->
        Directorio.register(user_id, credentials)
        Directorio.login(user_id, credentials)

      _ ->
        :ok
    end
  end

  defp load_wallet(user_id) do
    case Directorio.get_wallet(user_id) do
      {:ok, positions} ->
        {:ok, balance} = Directorio.get_balance(user_id)
        {:ok, price} = Directorio.current_price("BTC")
        %{balance: balance, positions: positions, current_price: price}

      _ ->
        %{balance: 0.0, positions: %{}, current_price: 0.0}
    end
  end

  defp update_wallet_prices(wallet, price) do
    %{wallet | current_price: price}
  end

  defp format_price(price) when is_number(price) do
    :erlang.float_to_binary(price / 1, decimals: 2)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="min-height:100vh;background:#0a0e17;">
      <header style="background:#141926;border-bottom:1px solid #1e293b;padding:0.75rem 1.5rem;display:flex;align-items:center;justify-content:space-between;">
        <div style="display:flex;align-items:center;gap:1rem;">
          <h1 style="font-size:1.25rem;font-weight:700;color:#f0f4f8;">Wall Street</h1>
          <span style="font-size:0.8rem;color:#64748b;">|</span>
          <span style="font-size:0.85rem;color:#94a3b8;">{@user_id}</span>
        </div>
        <div style="display:flex;align-items:center;gap:1.5rem;">
          <div style="text-align:right;">
            <span style="font-size:0.7rem;color:#64748b;display:block;">BTC</span>
            <span style={"font-size:1.1rem;font-weight:700;" <>
              if(@current_price >= @previous_price, do: "color:#34d399;", else: "color:#f87171;")}>
              ${format_price(@current_price)}
            </span>
          </div>
          <button phx-click="logout" style="padding:0.4rem 1rem;background:#1e293b;color:#94a3b8;border:1px solid #334155;border-radius:6px;cursor:pointer;font-size:0.8rem;">
            Salir
          </button>
        </div>
      </header>

      <NotificationComponent.render notifications={@notifications} />

      <div style="max-width:1200px;margin:0 auto;padding:1.5rem;display:grid;grid-template-columns:1fr 360px;gap:1.5rem;">
        <div style="display:flex;flex-direction:column;gap:1.5rem;">
          <GraphComponent.render
            price_history={@price_history}
            current_price={@current_price}
            previous_price={@previous_price}
          />

          <WalletComponent.render wallet={@wallet} current_price={@current_price} />

          <div style="background:#141926;border:1px solid #1e293b;border-radius:12px;padding:1.25rem;">
            <button phx-click="toggle_history" style="width:100%;display:flex;align-items:center;justify-content:space-between;background:none;border:none;color:#e2e8f0;cursor:pointer;">
              <h3 style="font-size:0.95rem;font-weight:600;">Historial de Transacciones</h3>
              <span style="color:#64748b;font-size:0.8rem;">{if @show_history, do: "Ocultar", else: "Mostrar"}</span>
            </button>
            <div :if={@show_history} style="margin-top:1rem;">
              <div :if={@transactions == []} style="color:#64748b;font-size:0.85rem;text-align:center;padding:1rem;">
                Sin transacciones
              </div>
              <div :for={tx <- @transactions} style="display:flex;justify-content:space-between;align-items:center;padding:0.6rem 0;border-bottom:1px solid #1e293b;">
                <div>
                  <span style={"font-size:0.8rem;font-weight:600;padding:0.15rem 0.5rem;border-radius:4px;" <>
                    if(tx.type == :buy, do: "background:#065f46;color:#34d399;", else: "background:#7f1d1d;color:#f87171;")}>
                    {if tx.type == :buy, do: "COMPRA", else: "VENTA"}
                  </span>
                  <span style="margin-left:0.75rem;font-size:0.85rem;color:#94a3b8;">
                    {tx.quantity} {tx.asset}
                  </span>
                </div>
                <span style="font-size:0.85rem;color:#e2e8f0;">${format_price(tx.price * tx.quantity)}</span>
              </div>
            </div>
          </div>
        </div>

        <div>
          <OrderComponent.render order_type={@order_type} quantity={@quantity} current_price={@current_price} wallet={@wallet} input_mode={@input_mode} />
        </div>
      </div>
    </div>
    """
  end
end
