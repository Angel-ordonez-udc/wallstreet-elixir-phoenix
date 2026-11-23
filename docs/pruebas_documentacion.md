# Documentación de Pruebas

## Tipos de pruebas realizadas

### Pruebas Manuales con IEx
Se realizaron pruebas interactivas utilizando la consola de Elixir (`iex -S mix`) para validar el comportamiento del backend. Estas pruebas incluyen:
- Registro y autenticación de usuarios.
- Operaciones de compra y venta de activos.
- Consulta de saldos, carteras y historial de transacciones.
- Suscripción y recepción de notificaciones de precio.
- Manejo de errores comunes, como credenciales inválidas o fondos insuficientes.

### Pruebas de Integración entre Servicios OTP
Se probaron las interacciones entre los diferentes servidores OTP (GenServers, Supervisores y PubSub):
- Comunicación entre `MarketServer`, `NotificationsServer`, `OperationsServer` y `GraphsServer`.
- Flujo de datos a través de PubSub para actualizaciones de precios y notificaciones.
- Persistencia de datos en el repositorio Mnesia.
- Supervisión automática de procesos, verificando que los procesos fallidos se reinicien correctamente.

### Pruebas de Comportamiento de Errores Esperados
Se validaron escenarios de error para asegurar robustez:
- Intentos de login con credenciales incorrectas.
- Operaciones de compra/venta con fondos insuficientes o activos no disponibles.
- Acceso a datos de usuarios no registrados o procesos inexistentes.
- Validación de límites en operaciones financieras.

### Pruebas de Estrés y Concurrencia
Se implementaron pruebas automatizadas con ExUnit para evaluar el rendimiento bajo carga:
- Pruebas de concurrencia con 10 usuarios registrándose y logueándose simultáneamente.
- Pruebas de estrés con 50 usuarios concurrentes, verificando estabilidad del sistema OTP y manejo de múltiples procesos.

## Escenarios cubiertos

### Gestión de Usuarios
- Registro exitoso de nuevos usuarios con credenciales válidas.
- Inicio de sesión y creación automática de procesos por usuario.
- Autenticación correcta y manejo de credenciales inválidas.
- Logout y terminación de procesos de usuario.

### Operaciones Financieras
- Consulta de saldo inicial (10000.0 por defecto) y cartera vacía tras login.
- Compra de activos con actualización correcta de balance y posiciones en cartera.
- Venta de activos poseídos, reflejando cambios en saldo y eliminación de posiciones.
- Historial de transacciones que registra todas las operaciones realizadas.
- Validación de fondos suficientes para compras y existencia de activos para ventas.

### Notificaciones y Alertas
- Suscripción a alertas de precio basadas en el precio de compra de un activo.
- Notificación automática cuando el precio fluctúa más del 5% respecto al precio de referencia.
- Recepción de alertas en tiempo real a través de PubSub.
- Reset de notificaciones para permitir alertas repetidas.

### Integración y Supervisión
- Reinicio automático de procesos supervisados cuando fallan, gracias al árbol de supervisión OTP con estrategia `one_for_one`.
- Comunicación entre servicios vía Repositorio y PubSub.
- Persistencia de datos en Mnesia para usuarios, wallets y transacciones.
- Actualización en tiempo real de precios de mercado simulados.

### Pruebas de Estrés
- Registro y login concurrente de 50 usuarios sin fallos, verificando estabilidad del sistema bajo carga.

## Escenarios no cubiertos

### Pruebas Unitarias Específicas
- Pruebas unitarias detalladas para cada módulo individual (ej. funciones específicas de `UserServer`, `MarketServer`).
- Cobertura completa con herramientas como `ExUnit` para todas las funciones públicas y privadas.

### Validación de Límites de Mercado Reales
- Simulación de datos históricos de precios reales de criptomonedas.
- Validación de límites de mercado extremos (precios muy altos/bajos, volatilidad extrema).
- Integración con APIs externas para datos de mercado en tiempo real.

### Escenarios de Fallo de Red y Conectividad
- Pérdida de conexión entre servicios OTP.
- Fallos en la comunicación PubSub.
- Recuperación de datos tras reinicios del sistema.

### Pruebas de Interfaz de Usuario
- Validación completa del frontend Phoenix LiveView.
- Interacciones de usuario en el navegador (formularios, gráficos, notificaciones en UI).
- Compatibilidad con diferentes navegadores y dispositivos.

### Casos de Uso Avanzados
- Múltiples carteras simultáneas por usuario.
- Transacciones complejas con múltiples activos.
- Concurrencia masiva (ej. 50 usuarios).
- Pruebas de rendimiento y latencia bajo carga sostenida.
