--------------------------------------------------------------------------------
-- OpsFlow - Paquete de lógica de negocio de tickets
--
-- Un PACKAGE en PL/SQL = una "librería" con dos partes:
--   * SPEC (especificación): lo público, la "firma" de lo que se puede llamar.
--   * BODY (cuerpo): la implementación.
--------------------------------------------------------------------------------

CREATE OR REPLACE PACKAGE pkg_ops_ticket AS

  -- Calcula la fecha límite a partir de una fecha base y la prioridad.
  FUNCTION fn_calcular_fecha_limite (
    p_fecha_base   IN DATE,
    p_id_prioridad IN NUMBER
  ) RETURN DATE;

  -- Crea un ticket nuevo y devuelve su id. Centraliza las reglas de alta.
  PROCEDURE sp_crear_ticket (
    p_id_categoria IN  NUMBER,
    p_id_prioridad IN  NUMBER,
    p_titulo       IN  VARCHAR2,
    p_descripcion  IN  VARCHAR2 DEFAULT NULL,
    p_id_agente    IN  NUMBER   DEFAULT NULL,
    p_id_ticket    OUT NUMBER
  );

  -- Cambia el estado de un ticket aplicando todas las reglas de negocio.
  PROCEDURE sp_cambiar_estado (
    p_id_ticket  IN NUMBER,
    p_nuevo_est  IN VARCHAR2,
    p_usuario    IN VARCHAR2 DEFAULT USER
  );

END pkg_ops_ticket;
/

CREATE OR REPLACE PACKAGE BODY pkg_ops_ticket AS

  --------------------------------------------------------------------------
  FUNCTION fn_calcular_fecha_limite (
    p_fecha_base   IN DATE,
    p_id_prioridad IN NUMBER
  ) RETURN DATE
  IS
    v_sla_horas ops_prioridad.sla_horas%TYPE;
  BEGIN
    SELECT sla_horas
      INTO v_sla_horas
      FROM ops_prioridad
     WHERE id_prioridad = p_id_prioridad;

    -- En Oracle, sumar horas a un DATE = sumar (horas/24).
    RETURN p_fecha_base + (v_sla_horas / 24);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20001, 'La prioridad indicada no existe.');
  END fn_calcular_fecha_limite;

  --------------------------------------------------------------------------
  PROCEDURE sp_crear_ticket (
    p_id_categoria IN  NUMBER,
    p_id_prioridad IN  NUMBER,
    p_titulo       IN  VARCHAR2,
    p_descripcion  IN  VARCHAR2 DEFAULT NULL,
    p_id_agente    IN  NUMBER   DEFAULT NULL,
    p_id_ticket    OUT NUMBER
  )
  IS
  BEGIN
    INSERT INTO ops_ticket (
      id_categoria, id_prioridad, id_agente, titulo, descripcion,
      estado, fecha_creacion, fecha_limite
    ) VALUES (
      p_id_categoria, p_id_prioridad, p_id_agente, p_titulo, p_descripcion,
      'NUEVO', SYSDATE, fn_calcular_fecha_limite(SYSDATE, p_id_prioridad)
    )
    RETURNING id_ticket INTO p_id_ticket;

    -- El historial del alta lo registra el trigger (ver 02_trg_ops_ticket.sql).
  END sp_crear_ticket;

  --------------------------------------------------------------------------
  PROCEDURE sp_cambiar_estado (
    p_id_ticket  IN NUMBER,
    p_nuevo_est  IN VARCHAR2,
    p_usuario    IN VARCHAR2 DEFAULT USER
  )
  IS
    v_estado_actual ops_ticket.estado%TYPE;
    v_fecha_limite  ops_ticket.fecha_limite%TYPE;
  BEGIN
    -- Bloqueamos la fila para evitar cambios concurrentes.
    SELECT estado, fecha_limite
      INTO v_estado_actual, v_fecha_limite
      FROM ops_ticket
     WHERE id_ticket = p_id_ticket
       FOR UPDATE;

    -- Regla: un ticket CERRADO ya no se modifica.
    IF v_estado_actual = 'CERRADO' THEN
      RAISE_APPLICATION_ERROR(-20002, 'El ticket está cerrado y no admite cambios.');
    END IF;

    IF p_nuevo_est = 'RESUELTO' THEN
      -- Al resolver: registrar fecha y determinar cumplimiento de SLA.
      UPDATE ops_ticket
         SET estado           = 'RESUELTO',
             fecha_resolucion = SYSDATE,
             cumplio_sla      = CASE WHEN SYSDATE <= v_fecha_limite THEN 'S' ELSE 'N' END
       WHERE id_ticket = p_id_ticket;
    ELSE
      UPDATE ops_ticket
         SET estado = p_nuevo_est
       WHERE id_ticket = p_id_ticket;
    END IF;
    -- La auditoría del cambio la hace el trigger automáticamente.
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20003, 'El ticket indicado no existe.');
  END sp_cambiar_estado;

END pkg_ops_ticket;
/

PROMPT ============================================================
PROMPT  OpsFlow: paquete PKG_OPS_TICKET compilado.
PROMPT ============================================================
