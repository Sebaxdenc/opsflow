--------------------------------------------------------------------------------
-- OpsFlow - Vistas de métricas para el Dashboard
--
-- Una VIEW es una consulta guardada con nombre. En APEX apuntás una región/gráfico
-- a la vista y listo: la lógica compleja queda en la base, no en la interfaz.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Vista enriquecida de tickets (con nombres en vez de IDs) -> ideal para reportes.
--------------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_ticket_detalle AS
SELECT t.id_ticket,
       t.titulo,
       t.descripcion,
       t.estado,
       c.nombre                         AS categoria,
       p.nombre                         AS prioridad,
       p.sla_horas,
       NVL(a.nombre, 'Sin asignar')     AS agente,
       t.fecha_creacion,
       t.fecha_limite,
       t.fecha_resolucion,
       t.cumplio_sla,
       -- ¿Está vencido y aún sin resolver?
       CASE
         WHEN t.estado IN ('NUEVO','EN_PROCESO') AND SYSDATE > t.fecha_limite
         THEN 'S' ELSE 'N'
       END                              AS vencido,
       -- Horas transcurridas hasta la resolución (o hasta ahora si sigue abierto).
       ROUND((NVL(t.fecha_resolucion, SYSDATE) - t.fecha_creacion) * 24, 1)
                                        AS horas_transcurridas
  FROM ops_ticket    t
  JOIN ops_categoria c ON c.id_categoria = t.id_categoria
  JOIN ops_prioridad p ON p.id_prioridad = t.id_prioridad
  LEFT JOIN ops_agente a ON a.id_agente = t.id_agente;

--------------------------------------------------------------------------------
-- KPIs generales (una sola fila) -> para las "cards" del dashboard.
--------------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_dashboard_kpi AS
SELECT
  COUNT(*)                                                          AS total_tickets,
  COUNT(CASE WHEN estado IN ('NUEVO','EN_PROCESO') THEN 1 END)      AS tickets_abiertos,
  COUNT(CASE WHEN estado = 'RESUELTO' THEN 1 END)                   AS tickets_resueltos,
  COUNT(CASE WHEN estado IN ('NUEVO','EN_PROCESO')
              AND SYSDATE > fecha_limite THEN 1 END)                AS tickets_vencidos,
  -- % cumplimiento SLA sobre los resueltos (evita división por cero).
  ROUND(
    100 * COUNT(CASE WHEN estado = 'RESUELTO' AND cumplio_sla = 'S' THEN 1 END)
        / NULLIF(COUNT(CASE WHEN estado = 'RESUELTO' THEN 1 END), 0)
  , 1)                                                              AS pct_cumplimiento_sla,
  -- Tiempo promedio de resolución en horas.
  ROUND(
    AVG(CASE WHEN estado = 'RESUELTO'
             THEN (fecha_resolucion - fecha_creacion) * 24 END)
  , 1)                                                              AS horas_prom_resolucion
FROM ops_ticket;

--------------------------------------------------------------------------------
-- Tickets abiertos agrupados por prioridad -> gráfico de torta/barras.
--------------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_tickets_por_prioridad AS
SELECT p.nombre AS prioridad,
       COUNT(t.id_ticket) AS cantidad
  FROM ops_prioridad p
  LEFT JOIN ops_ticket t
         ON t.id_prioridad = p.id_prioridad
        AND t.estado IN ('NUEVO','EN_PROCESO')
 GROUP BY p.nombre
 ORDER BY cantidad DESC;

--------------------------------------------------------------------------------
-- Carga por agente (tickets abiertos) -> gráfico de barras.
--------------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_carga_agente AS
SELECT NVL(a.nombre, 'Sin asignar') AS agente,
       COUNT(t.id_ticket)           AS tickets_abiertos
  FROM ops_ticket t
  LEFT JOIN ops_agente a ON a.id_agente = t.id_agente
 WHERE t.estado IN ('NUEVO','EN_PROCESO')
 GROUP BY NVL(a.nombre, 'Sin asignar')
 ORDER BY tickets_abiertos DESC;

PROMPT ============================================================
PROMPT  OpsFlow: vistas de métricas creadas.
PROMPT ============================================================
