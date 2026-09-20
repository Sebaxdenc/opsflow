# OpsFlow — Alcance funcional y diseño

> Portal de Gestión y Métricas de Servicios construido en Oracle APEX, SQL y PL/SQL.
> Proyecto personal orientado a demostrar competencias en desarrollo low-code empresarial,
> modelado de datos relacional, lógica de negocio en PL/SQL y analítica de procesos.

---

## 1. Problema que resuelve

En muchas organizaciones, las **solicitudes operativas** (incidencias, requerimientos de
soporte, cambios) se gestionan por correo o planillas. Esto genera:

- Pérdida de trazabilidad (¿quién atiende qué? ¿en qué estado está?).
- Incumplimiento de **SLA** (Service Level Agreement / Acuerdo de Nivel de Servicio) sin que nadie lo note.
- Falta de métricas para tomar decisiones (tiempos de atención, carga por agente, etc.).

**OpsFlow** centraliza estas solicitudes, calcula el cumplimiento de SLA automáticamente y
expone un panel de métricas para la toma de decisiones.

---

## 2. Módulos de la aplicación

| Módulo | Descripción | Páginas APEX típicas |
|---|---|---|
| **Dashboard** | Panel con KPIs y gráficos (tickets abiertos, % cumplimiento SLA, carga por agente). | 1 página con regiones tipo *Chart* y *Cards*. |
| **Solicitudes (Tickets)** | ABM (alta/baja/modificación) de solicitudes con formulario modal. | 1 *Interactive Report* + 1 *Modal Form*. |
| **Catálogos** | Mantenimiento de categorías, prioridades y agentes. | *Interactive Grids*. |
| **Reportes** | Reportes dinámicos filtrables (por estado, prioridad, agente, fecha). | *Interactive Report*. |

---

## 3. Reglas de negocio

1. **Cada prioridad define un SLA en horas** (ej: Crítica = 4h, Alta = 8h, Media = 24h, Baja = 72h).
2. Al **crear** un ticket, el sistema calcula automáticamente la **fecha límite de resolución**
   (`fecha_limite = fecha_creacion + SLA_horas`).
3. Cuando un ticket pasa a estado **RESUELTO**, se registra `fecha_resolucion` y se determina si
   **cumplió o incumplió** el SLA (`fecha_resolucion <= fecha_limite`).
4. Toda transición de estado queda **auditada** (quién, cuándo, de qué estado a qué estado).
5. Un ticket **cerrado no puede volver a modificarse** (regla de integridad de negocio).

---

## 4. Modelo de datos (diagrama entidad-relación)

```
+-------------------+          +--------------------+
|   OPS_CATEGORIA   |          |   OPS_PRIORIDAD    |
+-------------------+          +--------------------+
| PK id_categoria   |          | PK id_prioridad    |
|    nombre         |          |    nombre          |
|    descripcion    |          |    sla_horas       |
|    activo         |          |    activo          |
+---------+---------+          +----------+---------+
          |                               |
          | 1                           1 |
          |                               |
          | N                           N |
+---------v-------------------------------v---------+
|                   OPS_TICKET                      |
+---------------------------------------------------+
| PK  id_ticket                                     |
| FK  id_categoria   -> OPS_CATEGORIA               |
| FK  id_prioridad   -> OPS_PRIORIDAD               |
| FK  id_agente      -> OPS_AGENTE (nullable)       |
|     titulo                                        |
|     descripcion                                   |
|     estado         (NUEVO/EN_PROCESO/RESUELTO/CERRADO) |
|     fecha_creacion                                |
|     fecha_limite     (calculada)                  |
|     fecha_resolucion (calculada)                  |
|     cumplio_sla      (S/N, calculada)             |
+---------------------+-----------------------------+
          |                          |
          | 1                        | 1
          | N                        | N
+---------v---------+     +----------v--------------+
|   OPS_AGENTE      |     |  OPS_TICKET_HISTORIAL   |
+-------------------+     +-------------------------+
| PK id_agente      |     | PK id_historial         |
|    nombre         |     | FK id_ticket -> OPS_TICKET |
|    email          |     |    estado_anterior      |
|    activo         |     |    estado_nuevo         |
+-------------------+     |    usuario              |
                          |    fecha_cambio         |
                          +-------------------------+
```

**Cardinalidades:**
- Una **categoría** tiene muchos **tickets** (1:N).
- Una **prioridad** tiene muchos **tickets** (1:N).
- Un **agente** puede tener muchos **tickets** asignados (1:N, opcional).
- Un **ticket** tiene muchos registros en el **historial** (1:N).

---

## 5. Diccionario de datos

### OPS_CATEGORIA
| Columna | Tipo | Nulo | Descripción |
|---|---|---|---|
| id_categoria | NUMBER | NO (PK) | Identificador único. |
| nombre | VARCHAR2(60) | NO | Nombre de la categoría (ej: "Redes"). |
| descripcion | VARCHAR2(200) | SÍ | Detalle opcional. |
| activo | CHAR(1) | NO | 'S'/'N'. Permite desactivar sin borrar. |

### OPS_PRIORIDAD
| Columna | Tipo | Nulo | Descripción |
|---|---|---|---|
| id_prioridad | NUMBER | NO (PK) | Identificador único. |
| nombre | VARCHAR2(30) | NO | Ej: "Crítica", "Alta". |
| sla_horas | NUMBER | NO | Horas de SLA para esta prioridad. |
| activo | CHAR(1) | NO | 'S'/'N'. |

### OPS_AGENTE
| Columna | Tipo | Nulo | Descripción |
|---|---|---|---|
| id_agente | NUMBER | NO (PK) | Identificador único. |
| nombre | VARCHAR2(100) | NO | Nombre del agente. |
| email | VARCHAR2(120) | NO (UNIQUE) | Correo, único. |
| activo | CHAR(1) | NO | 'S'/'N'. |

### OPS_TICKET
| Columna | Tipo | Nulo | Descripción |
|---|---|---|---|
| id_ticket | NUMBER | NO (PK) | Identificador único. |
| id_categoria | NUMBER | NO (FK) | Categoría de la solicitud. |
| id_prioridad | NUMBER | NO (FK) | Prioridad (define el SLA). |
| id_agente | NUMBER | SÍ (FK) | Agente asignado (puede quedar sin asignar). |
| titulo | VARCHAR2(150) | NO | Resumen corto. |
| descripcion | VARCHAR2(2000) | SÍ | Detalle del problema. |
| estado | VARCHAR2(20) | NO | NUEVO / EN_PROCESO / RESUELTO / CERRADO. |
| fecha_creacion | DATE | NO | Se setea al insertar. |
| fecha_limite | DATE | SÍ | Calculada: creación + sla_horas. |
| fecha_resolucion | DATE | SÍ | Se setea al pasar a RESUELTO. |
| cumplio_sla | CHAR(1) | SÍ | 'S'/'N', calculada al resolver. |

### OPS_TICKET_HISTORIAL
| Columna | Tipo | Nulo | Descripción |
|---|---|---|---|
| id_historial | NUMBER | NO (PK) | Identificador único. |
| id_ticket | NUMBER | NO (FK) | Ticket al que pertenece. |
| estado_anterior | VARCHAR2(20) | SÍ | Estado previo (nulo en el alta). |
| estado_nuevo | VARCHAR2(20) | NO | Estado resultante. |
| usuario | VARCHAR2(60) | NO | Usuario que hizo el cambio. |
| fecha_cambio | DATE | NO | Momento del cambio. |

---

## 6. Métricas del Dashboard (analítica de procesos)

| KPI | Cómo se calcula |
|---|---|
| Tickets abiertos | Conteo de estado IN ('NUEVO','EN_PROCESO'). |
| % Cumplimiento SLA | Resueltos con cumplio_sla='S' / total resueltos * 100. |
| Tiempo promedio de resolución | AVG(fecha_resolucion - fecha_creacion) en horas. |
| Carga por agente | Conteo de tickets abiertos agrupado por agente. |
| Tickets por prioridad | Conteo agrupado por prioridad (gráfico de torta). |

---

