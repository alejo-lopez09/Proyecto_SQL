-- =====================================================================
-- Proyecto: Sistema de Reservas de Salones de Eventos
-- Script: triggers.sql
-- Descripción: Triggers de control y auditoría (CREATE TRIGGER)
-- =====================================================================

USE reservas_salones;

DELIMITER $$

-- ---------------------------------------------------------------------
-- tr_calcular_totales_reserva  (NO pedido explícitamente en el enunciado,
-- pero es necesario para cumplir "total de horas y valor total calculado
-- automáticamente" del requerimiento de Gestión de Reservas).
--
-- BEFORE INSERT: calcula total_horas y valor_total usando
-- calcular_total_reserva(), y rechaza la reserva si el salón no está
-- disponible en ese rango (usando verificar_disponibilidad()).
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_calcular_totales_reserva$$

CREATE TRIGGER tr_calcular_totales_reserva
BEFORE INSERT ON reservas
FOR EACH ROW
BEGIN
    DECLARE v_precio_hora DECIMAL(10,2);
    DECLARE v_horas DECIMAL(6,2);

    IF verificar_disponibilidad(NEW.id_salon, NEW.fecha_inicio, NEW.fecha_fin) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El salón no está disponible en el rango solicitado';
    END IF;

    SELECT precio_hora INTO v_precio_hora FROM salones WHERE id_salon = NEW.id_salon;
    SET v_horas = TIMESTAMPDIFF(MINUTE, NEW.fecha_inicio, NEW.fecha_fin) / 60.0;

    SET NEW.total_horas = v_horas;
    SET NEW.valor_total = calcular_total_reserva(v_precio_hora, v_horas);
END$$

-- ---------------------------------------------------------------------
-- actualizar_estado_salon_trigger
-- Al registrar una nueva reserva, el estado del salón cambia a 'Ocupado'.
--
-- ADVERTENCIA DE DISEÑO (ver README, sección de notas técnicas): esto
-- marca el salón como Ocupado de forma permanente e independiente de la
-- fecha de la reserva, incluso si la reserva es a futuro. Se implementa
-- así porque es lo que pide el enunciado, pero en un sistema real la
-- disponibilidad debería consultarse siempre con verificar_disponibilidad()
-- y no con este campo de estado.
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS actualizar_estado_salon_trigger$$

CREATE TRIGGER actualizar_estado_salon_trigger
AFTER INSERT ON reservas
FOR EACH ROW
BEGIN
    UPDATE salones
    SET estado = 'Ocupado'
    WHERE id_salon = NEW.id_salon
      AND estado = 'Disponible';
END$$

-- ---------------------------------------------------------------------
-- liberar_salon_trigger
-- Al eliminar una reserva, el salón vuelve a 'Disponible'
-- (solo si no estaba en mantenimiento).
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS liberar_salon_trigger$$

CREATE TRIGGER liberar_salon_trigger
AFTER DELETE ON reservas
FOR EACH ROW
BEGIN
    UPDATE salones
    SET estado = 'Disponible'
    WHERE id_salon = OLD.id_salon
      AND estado = 'Ocupado';
END$$

-- ---------------------------------------------------------------------
-- auditoria_precios_trigger
-- Al actualizar precio_hora en salones, registra usuario, fecha y
-- valores anterior/nuevo en auditoria_precios.
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS auditoria_precios_trigger$$

CREATE TRIGGER auditoria_precios_trigger
AFTER UPDATE ON salones
FOR EACH ROW
BEGIN
    IF OLD.precio_hora <> NEW.precio_hora THEN
        INSERT INTO auditoria_precios (id_salon, usuario, precio_anterior, precio_nuevo, fecha_cambio)
        VALUES (NEW.id_salon, CURRENT_USER(), OLD.precio_hora, NEW.precio_hora, NOW());
    END IF;
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- IMPORTANTE: tr_calcular_totales_reserva es BEFORE INSERT, así que solo
-- afecta reservas nuevas. Las reservas de prueba ya existían (se cargaron
-- en database.sql, antes de que este trigger existiera) y quedaron con
-- total_horas = 0 y valor_total = 0. Este UPDATE las recalcula una sola
-- vez para dejar los datos de prueba consistentes.
-- ---------------------------------------------------------------------
UPDATE reservas r
JOIN salones s ON s.id_salon = r.id_salon
SET r.total_horas = TIMESTAMPDIFF(MINUTE, r.fecha_inicio, r.fecha_fin) / 60.0,
    r.valor_total = calcular_total_reserva(s.precio_hora, TIMESTAMPDIFF(MINUTE, r.fecha_inicio, r.fecha_fin) / 60.0)
WHERE r.valor_total = 0;

-- ---------------------------------------------------------------------
-- Pruebas de los triggers
-- ---------------------------------------------------------------------

-- Estado del salón 3 antes de reservar
SELECT id_salon, nombre_salon, estado FROM salones WHERE id_salon = 3;

-- tr_calcular_totales_reserva + actualizar_estado_salon_trigger
INSERT INTO reservas (fecha_inicio, fecha_fin, id_cliente, id_salon, total_horas, valor_total)
VALUES ('2026-11-10 15:00:00', '2026-11-10 19:00:00', 2, 3, 0, 0);

SELECT id_reserva, total_horas, valor_total FROM reservas ORDER BY id_reserva DESC LIMIT 1;
SELECT id_salon, nombre_salon, estado FROM salones WHERE id_salon = 3; -- debe estar 'Ocupado'

-- liberar_salon_trigger
SET @ultima_reserva = LAST_INSERT_ID();
DELETE FROM reservas WHERE id_reserva = @ultima_reserva;
SELECT id_salon, nombre_salon, estado FROM salones WHERE id_salon = 3; -- vuelve a 'Disponible'

-- auditoria_precios_trigger
UPDATE salones SET precio_hora = 320000.00 WHERE id_salon = 3;
SELECT * FROM auditoria_precios;

-- Prueba de rechazo por choque de horario (descomentar para probar):
-- INSERT INTO reservas (fecha_inicio, fecha_fin, id_cliente, id_salon, total_horas, valor_total)
-- VALUES ('2026-09-05 09:00:00', '2026-09-05 11:00:00', 2, 1, 0, 0);
-- Debe lanzar: "El salón no está disponible en el rango solicitado"