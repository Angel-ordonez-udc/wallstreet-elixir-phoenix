# 📐 ADRs

## ADR-001: Arquitectura Cliente-Servidor
**Estado:** Aceptado  

**Decisión:** Implementar arquitectura cliente-servidor con un Directorio central que orquesta todos los servicios (Usuarios, Operaciones, Mercado, Gráficos, Notificaciones).  

**Consecuencias:**  
- Facilita reparto de trabajo entre 5 personas  
- Bajo acoplamiento y alta cohesión  
- Directorio es punto crítico (cuello de botella)  

---

## ADR-002: Interfaz web
**Estado:** Aceptado  

**Decisión:** Usar interfaz web con Phoenix en lugar de terminal.  

**Consecuencias:**  
- Más intuitiva para el usuario  
- Añadir nuevas funcionalidades implica modificar la interfaz

---

## ADR-003: Usuarios concurrentes
**Estado:** Aceptado  

**Decisión:** Soportar al menos 10 usuarios concurrentes inicialmente, escalable a más mediante PIDs y procesos de Elixir. 

**Consecuencias:**  
- Arquitectura escalable  
- Práctico para pruebas iniciales  
- Escalabilidad a más usuarios requerirá ajustes  

---

## ADR-004: Índices mostrados
**Estado:** Aceptado  

**Decisión:** Mostrar inicialmente un solo índice en la interfaz.  

**Consecuencias:**  
- Simplifica desarrollo y pruebas  
- Evita sobrecargar gráficos y servicios  
- Limitado, se puede ampliar en versiones futuras  

---

## ADR-005: Persistencia de datos
**Estado:** Aceptado  

**Decisión:** Guardar usuarios, transacciones y carteras en base de datos.

**Consecuencias:**  
- Reduce complejidad y latencia  
- Suficiente para la simulación  
- Algunos datos no persistirán entre reinicios  

---

## ADR-006: Fuente de datos para gráficas
**Estado:** Aceptado

**Decisión:** Usar datos precargados en un fichero o base de datos para que las gráficas muestren información ya creada.  

**Consecuencias:**  
- Permite probar la interfaz y simular el comportamiento de la bolsa sin depender de APIs externas  
- Añadir nuevas funcionalidades o cambiar los datos requerirá modificar el fichero o base de datos

## ADR-007: Monitorización de los servicios
**Estado:** Pendiente  

**Decisión:**  Era un requisito inicialmente planteado pero por falta de tiempo se ha decidido no implementarlo al completo. Existe ServiceBehaviour.status/0 pero no hay heartbeat activo que lo invoque periódicamente

