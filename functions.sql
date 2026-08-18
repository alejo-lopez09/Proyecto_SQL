-- =====================================================================
-- Proyecto: Sistema de Reservas de Salones de Eventos
-- Script: functions.sql
-- Descripción: Funciones personalizadas (CREATE FUNCTION)
-- =====================================================================

USE reservas_salones;

-- Si al ejecutar este script MySQL lanza el error 1418
-- ("This function has none of DETERMINISTIC..."), es porque
-- log_bin_trust_function_creators está en OFF. Se soluciona con:
-- SET GLOBAL log_bin_trust_function_creators = 1;

DELIMITER $$

-- ---------------------------------------------------------------------
-- calcular_total_reserva(precio_hora, horas)
-- Retorna el valor total con IVA (19%) de una reserva.
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS calcular_total_reserva$$

CREATE FUNCTION calcular_total_reserva(p_precio_hora DECIMAL(10,2), p_horas DECIMAL(6,2))
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    RETURN p_precio_hora * p_horas * 1.19;
END$$

-- ---------------------------------------------------------------------
-- verificar_disponibilidad(salon_id, fecha_inicio, fecha_fin)
-- Retorna 1 si el salón está disponible en ese rango, 0 si no.
--
-- Un salón NO está disponible si:
--   a) su estado es 'En mantenimiento', o
--   b) ya tiene una reserva que se solapa con el rango solicitado.
-- Solapamiento clásico: (inicio_existente < fin_nuevo) AND (fin_existente > inicio_nuevo)
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS verificar_disponibilidad$$

CREATE FUNCTION verificar_disponibilidad(
    p_salon_id INT,
    p_fecha_inicio DATETIME,
    p_fecha_fin DATETIME
)
RETURNS TINYINT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_estado VARCHAR(20);
    DECLARE v_conflictos INT;

    SELECT estado INTO v_estado FROM salones WHERE id_salon = p_salon_id;

    IF v_estado IS NULL OR v_estado = 'En mantenimiento' THEN
        RETURN 0;
    END IF;

    SELECT COUNT(*) INTO v_conflictos
    FROM reservas
    WHERE id_salon = p_salon_id
      AND fecha_inicio < p_fecha_fin
      AND fecha_fin > p_fecha_inicio;

    IF v_conflictos > 0 THEN
        RETURN 0;
    ELSE
        RETURN 1;
    END IF;
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- Pruebas de las funciones
-- ---------------------------------------------------------------------
SELECT calcular_total_reserva(150000.00, 4) AS total_con_iva_ejemplo;

-- Salón 1 tiene reserva 2026-09-05 08:00 a 12:00 -> debe chocar
SELECT verificar_disponibilidad(1, '2026-09-05 10:00:00', '2026-09-05 14:00:00') AS choca_con_reserva; -- 0
-- Mismo salón, horario que no choca
SELECT verificar_disponibilidad(1, '2026-09-06 08:00:00', '2026-09-06 12:00:00') AS libre_otro_dia;     -- 1
-- Salón 4 está en mantenimiento -> siempre 0, aunque el horario esté libre
SELECT verificar_disponibilidad(4, '2026-11-01 08:00:00', '2026-11-01 12:00:00') AS salon_mantenimiento; -- 0