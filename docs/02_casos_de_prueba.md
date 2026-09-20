# Casos de prueba — OpsFlow

> Documento funcional de QA. Cubre pruebas **unitarias** (lógica PL/SQL) y **funcionales**
> (comportamiento de la app en APEX). Formato de caso de prueba estándar: precondición,
> pasos, resultado esperado.

## 1. Pruebas unitarias (lógica de base de datos)

Automatizadas en `database/04_tests/01_pruebas_logica.sql`.

| ID | Caso | Precondición | Pasos | Resultado esperado |
|---|---|---|---|---|
| CP-01 | Cálculo de fecha límite | Existe prioridad "Alta" (SLA 8h) | Crear ticket con prioridad Alta | `fecha_limite = fecha_creacion + 8h` |
| CP-02 | Auditoría en el alta | — | Crear ticket | Se inserta 1 fila en historial con `estado_nuevo='NUEVO'` y `estado_anterior=NULL` |
| CP-03 | Cumplimiento de SLA | Ticket abierto dentro de plazo | Cambiar estado a RESUELTO | `estado='RESUELTO'` y `cumplio_sla='S'` |
| CP-04 | Auditoría de cambio de estado | Ticket recién resuelto | Consultar historial | Existe fila `NUEVO → RESUELTO` |
| CP-05 | Bloqueo de ticket cerrado | Ticket en estado CERRADO | Intentar cambiar estado | Lanza error `ORA-20002` |

## 2. Pruebas funcionales (aplicación APEX)

Ejecución manual en la app.

| ID | Caso | Pasos | Resultado esperado |
|---|---|---|---|
| CF-01 | Alta de solicitud | Abrir "Solicitudes" → Crear → completar y guardar | El ticket aparece en la grilla con estado NUEVO |
| CF-02 | Filtro por estado | En el reporte, filtrar por estado = EN_PROCESO | Solo se listan tickets en proceso |
| CF-03 | Exportación | Reporte → Actions → Download → CSV | Se descarga el CSV con las filas visibles |
| CF-04 | Resolver desde la UI | Abrir un ticket → botón Resolver | Estado pasa a RESUELTO y se calcula cumplimiento |
| CF-05 | KPI de SLA | Ir al Dashboard | La tarjeta "% Cumplimiento SLA" muestra un valor coherente con los datos |
| CF-06 | Gráfico por prioridad | Dashboard → gráfico de torta | Las porciones reflejan `vw_tickets_por_prioridad` |
| CF-07 | Validación de requeridos | Crear ticket sin título | La app impide guardar y muestra mensaje de campo obligatorio |

## 3. Cómo reportar un defecto (plantilla)

```
Título:        [Módulo] Descripción corta
Severidad:     Crítica / Alta / Media / Baja
Pasos:         1... 2... 3...
Esperado:      ...
Obtenido:      ...
Evidencia:     captura / query
```
