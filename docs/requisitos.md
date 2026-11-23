# 📑 REQUISITOS
## Requisitos funcionales
**RF01 - Tramitar órdenes**: el sistema debería permitir a los usuarios enviar órdenes de compra y venta de activos.

**RF02 - Registrarse**: el sistema debería permitir la creación de cuentas de usuario y la gestión de credenciales de seguridad.

**RF03 - Inicio de sesión**: el sistema debería permitir el inicio de sesión a un usuario mediante sus credenciales.

**RF04 - Visualizar cartera**: el sistema debería permitir visualizar en tiempo real el saldo disponible, activos en posesión y el cálculo de pérdidas/ganancias.

**RF05 - Historial de transacciones**: el sistema debería permitir consultar todas las operaciones ejecutadas con éxito en el pasado.

**RF06 - Visualizar gráficos**: el sistema debería permitir simular gráficos con datos actualizados en tiempo real.

**RF07 - Notificaciones**: el sistema debería notificar al usuario suscrito a un activo cuando se produzcan cambios del mismo dentro de un umbral.

## Requisitos no funcionales
**RNF01 - Latencia**:  el sistema debería realizar la ejecución de órdenes  en un tiempo mínimo para evitar el cambio de precio.

**RNF02 - Concurrencia de usuarios**: El servidor debe ser capaz de gestionar conexiones simultáneas (al menos 10 usuarios concurrentes) utilizando procesos ligeros de la BEAM, manteniendo un consumo de memoria eficiente (pocos KB por proceso).

**RNF03 - Gestión de errores y recuperación automática**: cualquier proceso que falle debido a un estado corrupto o excepción no controlada debe ser reiniciado automáticamente a un estado estable por su supervisor.

**RNF04 - Monitorización de los servicios**: el sistema debería implementar tácticas de "latidos" para detectar el estado de los servicios y notificar al balanceador de carga si un nodo deja de responder.
