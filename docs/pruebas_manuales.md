# Pruebas Manuales del Backend

Ejecutar estas pruebas desde la consola interactiva de Elixir:

```
iex --sname wallstreet -S mix
```

# Para no escribir el prefijo completo en todas las llamadas:
```elixir
alias WallstreetBackend.Directorio
```

---

## 1. Registro e inicio de sesión
El registro devuelve `:ok` y el login devuelve `{:ok, pid}`.
```elixir
Directorio.register("inversor1", %{"password" => "12345"})
# => :ok

{:ok, pid} = Directorio.login("inversor1", %{"password" => "12345"})
# => {:ok, #PID<...>}
```

## 2. Consultar el saldo inicial (por defecto 10000.0)
**Importante:** El usuario debe haber hecho login (paso 1) para que su proceso exista.
```elixir
Directorio.get_balance("inversor1")
# => {:ok, 10000.0}
```

## 3. Consultar la cartera inicial (vacía, sin posiciones)
```elixir
Directorio.get_wallet("inversor1")
# => {:ok, %{}}
```

## 4. Esperar a que el mercado cargue los precios
El MarketServer envía ticks cada segundo. Hay que esperar al menos 1-2 segundos
después de arrancar la app para que el precio de "BTC" se escriba en el Repo.
```elixir
:timer.sleep(2000)
```

## 5. Consultar el precio actual de BTC
```elixir
{:ok, precio_btc} = Directorio.current_price("BTC")
# => {:ok, <precio_numérico>}
```

## 6. Comprar un activo (ej. comprar 0.1 unidades de "BTC")
```elixir
{:ok, tx_compra} = Directorio.buy("inversor1", "BTC", 0.1)
# => {:ok, %WallstreetBackend.Operations.Transaction{type: :buy, asset: "BTC", quantity: 0.1, ...}}
```

## 7. Comprobar cartera y saldo tras la compra
Deberías ver BTC en la cartera y un balance menor.
```elixir
Directorio.get_wallet("inversor1")
# => {:ok, %{"BTC" => 0.1}}

Directorio.get_balance("inversor1")
# => {:ok, 10000.0 - precio_btc * 0.1}
```

## 8. Consultar historial de transacciones
```elixir
{:ok, historial} = Directorio.transaction_history("inversor1")
# => {:ok, [%Transaction{type: :buy, asset: "BTC", quantity: 0.1, ...}]}
```

## 9. Vender parte del activo (vender 0.1 unidad)
```elixir
{:ok, tx_venta} = Directorio.sell("inversor1", "BTC", 0.1)
# => {:ok, %Transaction{type: :sell, asset: "BTC", quantity: 0.1, ...}}
```

## 10. Revisar los datos tras la venta
```elixir
Directorio.get_wallet("inversor1")
# => {:ok, %{"BTC" => 0.1}}

Directorio.get_balance("inversor1")
# El balance habrá subido respecto al paso 7

{:ok, historial} = Directorio.transaction_history("inversor1")
# => {:ok, [%Transaction{type: :sell, ...}, %Transaction{type: :buy, ...}]}
# Debería contener tanto la compra como la venta
```

---

## 11. Pruebas de errores esperados

### Login con contraseña incorrecta
```elixir
Directorio.login("inversor1", %{"password" => "wrong"})
# => {:error, :invalid_credentials}
```

### Registrar usuario duplicado
```elixir
Directorio.register("inversor1", %{"password" => "otro"})
# => {:error, :user_already_exists}
```

### Comprar sin fondos suficientes
```elixir
Directorio.buy("inversor1", "BTC", 999_999)
# => {:error, :insufficient_funds}
```

### Vender más de lo que se posee
```elixir
Directorio.sell("inversor1", "BTC", 999)
# => {:error, :insufficient_assets}
```

### Vender un activo que no se posee
```elixir
Directorio.sell("inversor1", "ETH", 1)
# => {:error, :asset_not_found}
```

---

## 12. Notificaciones (alertas de precio)

Suscribirse a alertas cuando el precio varíe más del 10% respecto a un precio de referencia:
```elixir
{:ok, precio_actual} = Directorio.current_price("BTC")
Directorio.subscribe_alerts("inversor1", "BTC", precio_actual)
# => :ok
```

Ver alertas activas:
```elixir
WallstreetBackend.Notifications.NotificationsServer.list_alerts("inversor1")
# => [%{asset: "BTC", precio_compra: <precio>, notificado: false}]
```

Las alertas se dispararán automáticamente en los logs cuando el precio varíe ≥10%.

---

## 13. Logout
```elixir
Directorio.logout("inversor1")
# => :ok
```

Tras el logout, las operaciones sobre ese usuario fallarán (el proceso ya no existe):
```elixir
Directorio.get_balance("inversor1")
# => ** (exit) ...
```