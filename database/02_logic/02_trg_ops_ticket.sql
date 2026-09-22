--------------------------------------------------------------------------------
-- OpsFlow - Triggers de OPS_TICKET
--
-- Un TRIGGER es código que la base ejecuta AUTOMÁTICAMENTE ante un evento
-- (INSERT/UPDATE/DELETE). Nadie lo "llama": se dispara solo.
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Trigger 1: calcula fecha_limite al insertar, por si el ticket se crea
--            directamente por SQL/APEX sin pasar por el paquete.
--            (Defensa en profundidad: la regla se cumple SIEMPRE.)
--------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_ticket_biu
BEFORE INSERT ON ops_ticket
FOR EACH ROW
BEGIN
  IF :NEW.fecha_creacion IS NULL THEN
    :NEW.fecha_creacion := SYSDATE;
  END IF;

  IF :NEW.fecha_limite IS NULL THEN
    :NEW.fecha_limite :=
      pkg_ops_ticket.fn_calcular_fecha_limite(:NEW.fecha_creacion, :NEW.id_prioridad);
  END IF;

  IF :NEW.estado IS NULL THEN
    :NEW.estado := 'NUEVO';
  END IF;
END;
/

--------------------------------------------------------------------------------
-- Trigger 2: audita cada cambio de estado en OPS_TICKET_HISTORIAL.
--            Se dispara tanto en el alta (INSERT) como en cambios (UPDATE).
--------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_ticket_historial_aiu
AFTER INSERT OR UPDATE OF estado ON ops_ticket
FOR EACH ROW
BEGIN
  IF INSERTING OR (:OLD.estado <> :NEW.estado) THEN
    INSERT INTO ops_ticket_historial (
      id_ticket, estado_anterior, estado_nuevo, usuario, fecha_cambio
    ) VALUES (
      :NEW.id_ticket,
      :OLD.estado,     -- en INSERT vale NULL automáticamente
      :NEW.estado,
      USER,
      SYSDATE
    );
  END IF;
END;
/


PROMPT ============================================================
PROMPT  OpsFlow: triggers de OPS_TICKET creados.
PROMPT ============================================================
