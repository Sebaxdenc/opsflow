--------------------------------------------------------------------------------
-- OpsFlow - Datos de ejemplo (seed)
--
-- Objetivo: poblar la app con datos realistas para que el dashboard muestre
-- KPIs con sentido (tickets abiertos, resueltos a tiempo, resueltos tarde y vencidos).
--
-- Ejecutar DESPUÉS de crear el esquema y la lógica (tablas + paquete + triggers).
-- Es idempotente: limpia las tablas antes de insertar.
--------------------------------------------------------------------------------

-- Limpieza (respetar orden por las FK: primero hijas, luego padres).
DELETE FROM ops_ticket_historial;
DELETE FROM ops_ticket;
DELETE FROM ops_agente;
DELETE FROM ops_prioridad;
DELETE FROM ops_categoria;

--------------------------------------------------------------------------------
-- Catálogos
--------------------------------------------------------------------------------
INSERT INTO ops_categoria (nombre, descripcion) VALUES ('Redes',        'Conectividad, VPN, WiFi');
INSERT INTO ops_categoria (nombre, descripcion) VALUES ('Aplicaciones', 'Software de negocio y ERP');
INSERT INTO ops_categoria (nombre, descripcion) VALUES ('Hardware',     'Equipos y periféricos');
INSERT INTO ops_categoria (nombre, descripcion) VALUES ('Accesos',      'Altas, bajas y permisos');

-- SLA en horas por prioridad.
INSERT INTO ops_prioridad (nombre, sla_horas) VALUES ('Critica', 4);
INSERT INTO ops_prioridad (nombre, sla_horas) VALUES ('Alta',    8);
INSERT INTO ops_prioridad (nombre, sla_horas) VALUES ('Media',   24);
INSERT INTO ops_prioridad (nombre, sla_horas) VALUES ('Baja',    72);

INSERT INTO ops_agente (nombre, email) VALUES ('Ana Torres',   'ana.torres@opsflow.demo');
INSERT INTO ops_agente (nombre, email) VALUES ('Luis Prado',   'luis.prado@opsflow.demo');
INSERT INTO ops_agente (nombre, email) VALUES ('Marta Ruiz',   'marta.ruiz@opsflow.demo');

--------------------------------------------------------------------------------
-- Tickets
-- Usamos variables de bind con SELECT para no depender de IDs fijos.
-- Insertamos con fechas variadas para simular historia real.
--------------------------------------------------------------------------------
DECLARE
  -- Helpers para obtener IDs por nombre (más legible que hardcodear).
  FUNCTION cat(p VARCHAR2) RETURN NUMBER IS r NUMBER; BEGIN
    SELECT id_categoria INTO r FROM ops_categoria WHERE nombre = p; RETURN r; END;
  FUNCTION pri(p VARCHAR2) RETURN NUMBER IS r NUMBER; BEGIN
    SELECT id_prioridad INTO r FROM ops_prioridad WHERE nombre = p; RETURN r; END;
  FUNCTION age(p VARCHAR2) RETURN NUMBER IS r NUMBER; BEGIN
    SELECT id_agente INTO r FROM ops_agente WHERE nombre = p; RETURN r; END;

  -- Inserta un ticket con control fino de fechas y estado (para el demo).
  PROCEDURE mk (
    p_cat VARCHAR2, p_pri VARCHAR2, p_age VARCHAR2, p_titulo VARCHAR2,
    p_dias_atras NUMBER,          -- hace cuántos días se creó
    p_estado VARCHAR2,
    p_horas_resol NUMBER DEFAULT NULL  -- horas que tardó en resolverse (si aplica)
  ) IS
    v_id     NUMBER;
    v_fcreac DATE := SYSDATE - p_dias_atras;
  BEGIN
    INSERT INTO ops_ticket (id_categoria, id_prioridad, id_agente, titulo,
                            estado, fecha_creacion)
    VALUES (cat(p_cat), pri(p_pri),
            CASE WHEN p_age IS NULL THEN NULL ELSE age(p_age) END,
            p_titulo, 'NUEVO', v_fcreac)
    RETURNING id_ticket INTO v_id;
    -- El trigger ya calculó fecha_limite en base a la prioridad y fecha_creacion.

    IF p_estado = 'EN_PROCESO' THEN
      UPDATE ops_ticket SET estado = 'EN_PROCESO' WHERE id_ticket = v_id;
    ELSIF p_estado IN ('RESUELTO','CERRADO') THEN
      UPDATE ops_ticket
         SET estado = 'RESUELTO',
             fecha_resolucion = v_fcreac + (p_horas_resol/24),
             cumplio_sla = CASE WHEN v_fcreac + (p_horas_resol/24) <= fecha_limite
                                THEN 'S' ELSE 'N' END
       WHERE id_ticket = v_id;
      IF p_estado = 'CERRADO' THEN
        UPDATE ops_ticket SET estado = 'CERRADO' WHERE id_ticket = v_id;
      END IF;
    END IF;
  END;
BEGIN
  -- Abiertos (algunos vencidos por ser antiguos con SLA corto)
  mk('Redes',        'Critica', 'Ana Torres', 'Caída de enlace principal',        0.1, 'EN_PROCESO');
  mk('Aplicaciones', 'Alta',    'Luis Prado', 'ERP no permite facturar',          0.3, 'EN_PROCESO');
  mk('Accesos',      'Media',   NULL,         'Alta de usuario nuevo',            0.5, 'NUEVO');
  mk('Hardware',     'Baja',    'Marta Ruiz', 'Cambio de teclado',                1.0, 'NUEVO');
  mk('Redes',        'Alta',    'Ana Torres', 'WiFi intermitente piso 3',         2.0, 'EN_PROCESO'); -- vencido
  mk('Aplicaciones', 'Critica', 'Luis Prado', 'Error 500 en portal clientes',     0.5, 'NUEVO');      -- vencido

  -- Resueltos a tiempo (cumplieron SLA)
  mk('Accesos',      'Media',   'Marta Ruiz', 'Reset de contraseña',              3,   'RESUELTO', 2);
  mk('Hardware',     'Baja',    'Ana Torres', 'Instalación de impresora',         5,   'RESUELTO', 20);
  mk('Redes',        'Alta',    'Luis Prado', 'Configuración de VPN',             4,   'RESUELTO', 6);
  mk('Aplicaciones', 'Media',   'Marta Ruiz', 'Reporte de ventas no exporta',     6,   'CERRADO', 10);

  -- Resueltos tarde (incumplieron SLA)
  mk('Redes',        'Critica', 'Ana Torres', 'Firewall bloquea tráfico legítimo',7,   'RESUELTO', 12);
  mk('Aplicaciones', 'Alta',    'Luis Prado', 'Lentitud en módulo de inventario', 8,   'CERRADO', 30);

  COMMIT;
END;
/

PROMPT ============================================================
PROMPT  OpsFlow: datos de ejemplo cargados.
PROMPT  Verificá con:  SELECT * FROM vw_dashboard_kpi;
PROMPT ============================================================
