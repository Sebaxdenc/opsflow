--------------------------------------------------------------------------------
-- OpsFlow - Instalador completo
--
-- Ejecuta TODO en el orden correcto desde SQL*Plus / SQLcl.
-- En el SQL Workshop de apex.oracle.com podés, en cambio, abrir y correr cada
-- archivo por separado siguiendo este mismo orden (ver docs/02_guia_apex.md).
--
-- Uso (SQLcl):  @install_all.sql
--------------------------------------------------------------------------------
SET DEFINE OFF
SET SERVEROUTPUT ON

PROMPT >>> 1/4 Creando esquema...
@@01_schema/01_create_tables.sql

PROMPT >>> 2/4 Compilando lógica PL/SQL...
@@02_logic/01_pkg_ops_ticket.sql
@@02_logic/02_trg_ops_ticket.sql
@@02_logic/03_views_metricas.sql

PROMPT >>> 3/4 Cargando datos de ejemplo...
@@03_seed/01_seed_data.sql

PROMPT >>> 4/4 Verificación rápida
SELECT * FROM vw_dashboard_kpi;

PROMPT ============================================================
PROMPT  OpsFlow instalado. Continuá con docs/02_guia_apex.md
PROMPT ============================================================
