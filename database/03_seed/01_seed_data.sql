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
-- Insertamos con fechas variadas para simular historia real.
--------------------------------------------------------------------------------
DECLARE

  -- Inserta un ticket resolviendo los IDs por nombre DENTRO del procedimiento
  -- (con SELECT ... INTO) y usando variables en el INSERT.
  PROCEDURE mk (
    p_cat         VARCHAR2,
    p_pri         VARCHAR2,
    p_age         VARCHAR2,          -- nombre del agente, o NULL si sin asignar
    p_titulo      VARCHAR2,
    p_dias_atras  NUMBER,            -- hace cuántos días se creó
    p_estado      VARCHAR2,
    p_horas_resol NUMBER DEFAULT NULL  -- horas que tardó en resolverse (si aplica)
  ) IS
    v_id       NUMBER;
    v_id_cat   NUMBER;
    v_id_pri   NUMBER;
    v_id_age   NUMBER;
    v_fcreac   DATE := SYSDATE - p_dias_atras;
  BEGIN
    -- Resolver IDs por nombre (esto es SQL válido: SELECT ... INTO variable).
    SELECT id_categoria INTO v_id_cat FROM ops_categoria WHERE nombre = p_cat;
    SELECT id_prioridad INTO v_id_pri FROM ops_prioridad WHERE nombre = p_pri;
 
    IF p_age IS NULL THEN
      v_id_age := NULL;
    ELSE
      SELECT id_agente INTO v_id_age FROM ops_agente WHERE nombre = p_age;
    END IF;
 
    -- Alta del ticket. El trigger calcula fecha_limite segun la prioridad.
    INSERT INTO ops_ticket (id_categoria, id_prioridad, id_agente, titulo,
                            estado, fecha_creacion)
    VALUES (v_id_cat, v_id_pri, v_id_age, p_titulo, 'NUEVO', v_fcreac)
    RETURNING id_ticket INTO v_id;

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
  END mk;
BEGIN
  -- Abiertos (algunos vencidos por ser antiguos con SLA corto)
  mk('Redes',        'Critica', 'Ana Torres', 'Caida de enlace principal',        0.1, 'EN_PROCESO');
  mk('Aplicaciones', 'Alta',    'Luis Prado', 'ERP no permite facturar',          0.3, 'EN_PROCESO');
  mk('Accesos',      'Media',   NULL,         'Alta de usuario nuevo',            0.5, 'NUEVO');
  mk('Hardware',     'Baja',    'Marta Ruiz', 'Cambio de teclado',                1.0, 'NUEVO');
  mk('Redes',        'Alta',    'Ana Torres', 'WiFi intermitente piso 3',         2.0, 'EN_PROCESO'); -- vencido
  mk('Aplicaciones', 'Critica', 'Luis Prado', 'Error 500 en portal clientes',     0.5, 'NUEVO');      -- vencido

  -- Resueltos a tiempo (cumplieron SLA)
  mk('Accesos',      'Media',   'Marta Ruiz', 'Reset de contrasena',              3,   'RESUELTO', 2);
  mk('Hardware',     'Baja',    'Ana Torres', 'Instalacion de impresora',         5,   'RESUELTO', 20);
  mk('Redes',        'Alta',    'Luis Prado', 'Configuracion de VPN',             4,   'RESUELTO', 6);
  mk('Aplicaciones', 'Media',   'Marta Ruiz', 'Reporte de ventas no exporta',     6,   'CERRADO', 10);

  -- Resueltos tarde (incumplieron SLA)
  mk('Redes',        'Critica', 'Ana Torres', 'Firewall bloquea trafico legitimo',7,   'RESUELTO', 12);
  mk('Aplicaciones', 'Alta',    'Luis Prado', 'Lentitud en modulo de inventario', 8,   'CERRADO', 30);

  COMMIT;
END;
/

PROMPT ============================================================
PROMPT  OpsFlow: datos de ejemplo cargados.
PROMPT  Verificá con:  SELECT * FROM vw_dashboard_kpi;
PROMPT ============================================================
