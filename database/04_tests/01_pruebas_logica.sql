--------------------------------------------------------------------------------
-- OpsFlow - Pruebas de la lógica de negocio (smoke tests en PL/SQL)
--
-- No es un framework formal (utPLSQL), sino un script legible que valida las
-- reglas clave. Cada bloque imprime OK/FALLO por consola (SET SERVEROUTPUT ON).
--
--------------------------------------------------------------------------------
SET SERVEROUTPUT ON

DECLARE
  PROCEDURE assert (p_cond BOOLEAN, p_msg VARCHAR2) IS
  BEGIN
    IF p_cond THEN
      DBMS_OUTPUT.PUT_LINE('OK    - ' || p_msg);
    ELSE
      DBMS_OUTPUT.PUT_LINE('FALLO - ' || p_msg);
    END IF;
  END;

  v_id      NUMBER;
  v_limite  DATE;
  v_creac   DATE;
  v_estado  VARCHAR2(20);
  v_cumplio CHAR(1);
  v_hist    NUMBER;
  v_pri     NUMBER;
BEGIN
  SELECT id_prioridad INTO v_pri FROM ops_prioridad WHERE nombre = 'Alta'; -- SLA 8h

  -----------------------------------------------------------------------------
  -- CP-01: al crear un ticket, fecha_limite = creacion + SLA de la prioridad.
  -----------------------------------------------------------------------------
  pkg_ops_ticket.sp_crear_ticket(
    p_id_categoria => (SELECT id_categoria FROM ops_categoria WHERE nombre='Redes'),
    p_id_prioridad => v_pri,
    p_titulo       => 'TEST fecha limite',
    p_id_ticket    => v_id);

  SELECT fecha_creacion, fecha_limite INTO v_creac, v_limite
    FROM ops_ticket WHERE id_ticket = v_id;

  assert(ROUND((v_limite - v_creac)*24) = 8,
         'CP-01 fecha_limite = creacion + 8h (SLA Alta)');

  -----------------------------------------------------------------------------
  -- CP-02: el alta genera un registro en el historial (estado_nuevo = NUEVO).
  -----------------------------------------------------------------------------
  SELECT COUNT(*) INTO v_hist
    FROM ops_ticket_historial
   WHERE id_ticket = v_id AND estado_nuevo = 'NUEVO' AND estado_anterior IS NULL;
  assert(v_hist = 1, 'CP-02 el alta registra historial NUEVO');

  -----------------------------------------------------------------------------
  -- CP-03: resolver dentro del SLA marca cumplio_sla = S.
  -----------------------------------------------------------------------------
  pkg_ops_ticket.sp_cambiar_estado(v_id, 'RESUELTO');
  SELECT estado, cumplio_sla INTO v_estado, v_cumplio
    FROM ops_ticket WHERE id_ticket = v_id;
  assert(v_estado = 'RESUELTO' AND v_cumplio = 'S',
         'CP-03 resolver a tiempo -> cumplio_sla = S');

  -----------------------------------------------------------------------------
  -- CP-04: el cambio de estado se audita en el historial.
  -----------------------------------------------------------------------------
  SELECT COUNT(*) INTO v_hist
    FROM ops_ticket_historial
   WHERE id_ticket = v_id AND estado_anterior = 'NUEVO' AND estado_nuevo = 'RESUELTO';
  assert(v_hist = 1, 'CP-04 el cambio de estado se audita');

  -----------------------------------------------------------------------------
  -- CP-05: un ticket CERRADO no admite más cambios (debe lanzar error).
  -----------------------------------------------------------------------------
  pkg_ops_ticket.sp_cambiar_estado(v_id, 'CERRADO');
  BEGIN
    pkg_ops_ticket.sp_cambiar_estado(v_id, 'EN_PROCESO');
    assert(FALSE, 'CP-05 modificar ticket cerrado debe fallar');
  EXCEPTION
    WHEN OTHERS THEN
      assert(SQLCODE = -20002, 'CP-05 modificar ticket cerrado lanza ORA-20002');
  END;

  -- Limpieza del ticket de prueba (dejamos la base como estaba).
  DELETE FROM ops_ticket_historial WHERE id_ticket = v_id;
  DELETE FROM ops_ticket WHERE id_ticket = v_id;
  COMMIT;

  DBMS_OUTPUT.PUT_LINE('--- Pruebas finalizadas ---');
END;
/
