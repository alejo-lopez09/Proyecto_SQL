-- =====================================================================
-- Proyecto: Sistema de Reservas de Salones de Eventos
-- Script: views_and_queries.sql
-- Descripción: Vistas (CREATE VIEW) y consultas SQL requeridas
-- =====================================================================

USE reservas_salones;

-- =====================================================================
-- VISTA
-- =====================================================================

-- ---------------------------------------------------------------------
-- vista_resumen_reservas
-- Nombre del cliente, nombre del salón, fecha de inicio, fecha fin,
-- total y estado (estado de la reserva respecto al pago: Pagada /
-- Pendiente, ya que "estado" en el enunciado de reservas no está
-- definido como columna propia -- se infiere del cruce con pagos).
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS vista_resumen_reservas;

CREATE VIEW vista_resumen_reservas AS
SELECT
    r.id_reserva,
    c.nombre_completo AS cliente,
    s.nombre_salon AS salon,
    r.fecha_inicio,
    r.fecha_fin,
    r.valor_total AS total,
    CASE
        WHEN IFNULL(SUM(p.monto_pagado), 0) >= r.valor_total THEN 'Pagada'
        WHEN IFNULL(SUM(p.monto_pagado), 0) > 0 THEN 'Pago parcial'
        ELSE 'Pendiente'
    END AS estado
FROM reservas r
JOIN clientes c ON c.id_cliente = r.id_cliente
JOIN salones s ON s.id_salon = r.id_salon
LEFT JOIN pagos p ON p.id_reserva = r.id_reserva
GROUP BY r.id_reserva, c.nombre_completo, s.nombre_salon, r.fecha_inicio, r.fecha_fin, r.valor_total;

SELECT * FROM vista_resumen_reservas;

-- =====================================================================
-- CONSULTAS SQL REQUERIDAS
-- =====================================================================

-- 1. Reservas realizadas en un rango de fechas (BETWEEN)
SELECT id_reserva, fecha_inicio, fecha_fin, id_cliente, id_salon, valor_total
FROM reservas
WHERE fecha_inicio BETWEEN '2026-09-01' AND '2026-09-30';

-- 2. Salones con capacidad mayor a X personas y estado = 'Disponible'
--    (X = 50 como ejemplo; cambiar el valor según necesidad)
SELECT id_salon, nombre_salon, capacidad, precio_hora, estado
FROM salones
WHERE capacidad > 50
  AND estado = 'Disponible';

-- 3. Clientes corporativos que hayan hecho más de 3 reservas
SELECT
    c.id_cliente,
    c.nombre_completo,
    COUNT(r.id_reserva) AS total_reservas
FROM clientes c
JOIN reservas r ON r.id_cliente = c.id_cliente
WHERE c.tipo_cliente = 'Corporativo'
GROUP BY c.id_cliente, c.nombre_completo
HAVING COUNT(r.id_reserva) > 3;

-- Variante con subconsulta (equivalente a la anterior, por si el
-- profesor pide explícitamente el enfoque de subconsulta):
SELECT id_cliente, nombre_completo
FROM clientes
WHERE tipo_cliente = 'Corporativo'
  AND id_cliente IN (
      SELECT id_cliente
      FROM reservas
      GROUP BY id_cliente
      HAVING COUNT(*) > 3
  );