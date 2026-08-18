-- =====================================================================
-- Proyecto: Sistema de Reservas de Salones de Eventos — Eventos Premier S.A.S.
-- Script: database.sql
-- Descripción: Creación de la base de datos, tablas, relaciones e
--              inserción de datos de prueba.
-- Motor: MySQL 8.x
-- =====================================================================

DROP DATABASE IF EXISTS reservas_salones;
CREATE DATABASE reservas_salones CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE reservas_salones;

-- ---------------------------------------------------------------------
-- Tabla: salones
-- ---------------------------------------------------------------------
CREATE TABLE salones (
    id_salon INT AUTO_INCREMENT PRIMARY KEY,
    nombre_salon VARCHAR(100) NOT NULL,
    capacidad INT NOT NULL CHECK (capacidad > 0),
    precio_hora DECIMAL(10,2) NOT NULL CHECK (precio_hora >= 0),
    estado ENUM('Disponible', 'Ocupado', 'En mantenimiento') NOT NULL DEFAULT 'Disponible',
    encargado VARCHAR(100) NOT NULL
);

-- ---------------------------------------------------------------------
-- Tabla: clientes
-- ---------------------------------------------------------------------
CREATE TABLE clientes (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nombre_completo VARCHAR(150) NOT NULL,
    identificacion VARCHAR(20) NOT NULL UNIQUE,
    telefono VARCHAR(20),
    correo_electronico VARCHAR(120),
    tipo_cliente ENUM('Individual', 'Corporativo') NOT NULL DEFAULT 'Individual'
);

-- ---------------------------------------------------------------------
-- Tabla: reservas
-- total_horas y valor_total se calculan automáticamente vía trigger
-- (ver triggers.sql -> tr_calcular_totales_reserva)
-- ---------------------------------------------------------------------
CREATE TABLE reservas (
    id_reserva INT AUTO_INCREMENT PRIMARY KEY,
    fecha_inicio DATETIME NOT NULL,
    fecha_fin DATETIME NOT NULL,
    id_cliente INT NOT NULL,
    id_salon INT NOT NULL,
    total_horas DECIMAL(6,2) NOT NULL DEFAULT 0,
    valor_total DECIMAL(12,2) NOT NULL DEFAULT 0,
    CONSTRAINT chk_fechas_reserva CHECK (fecha_fin > fecha_inicio),
    CONSTRAINT fk_reservas_cliente FOREIGN KEY (id_cliente)
        REFERENCES clientes(id_cliente)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_reservas_salon FOREIGN KEY (id_salon)
        REFERENCES salones(id_salon)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- ---------------------------------------------------------------------
-- Tabla: pagos
-- ---------------------------------------------------------------------
CREATE TABLE pagos (
    id_pago INT AUTO_INCREMENT PRIMARY KEY,
    id_reserva INT NOT NULL,
    fecha_pago DATE NOT NULL,
    monto_pagado DECIMAL(12,2) NOT NULL CHECK (monto_pagado > 0),
    metodo_pago ENUM('Efectivo', 'Tarjeta', 'Transferencia') NOT NULL,
    CONSTRAINT fk_pagos_reserva FOREIGN KEY (id_reserva)
        REFERENCES reservas(id_reserva)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- Tabla: auditoria_precios
-- ---------------------------------------------------------------------
CREATE TABLE auditoria_precios (
    id_auditoria INT AUTO_INCREMENT PRIMARY KEY,
    id_salon INT NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    precio_anterior DECIMAL(10,2) NOT NULL,
    precio_nuevo DECIMAL(10,2) NOT NULL,
    fecha_cambio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_auditoria_salon FOREIGN KEY (id_salon)
        REFERENCES salones(id_salon)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- =====================================================================
-- DATOS DE PRUEBA
-- =====================================================================

-- Salones
INSERT INTO salones (nombre_salon, capacidad, precio_hora, estado, encargado) VALUES
('Salón Esmeralda', 150, 250000.00, 'Disponible', 'Marcela Duarte'),
('Salón Zafiro', 80, 150000.00, 'Disponible', 'Jorge Peña'),
('Salón Rubí (VIP)', 40, 300000.00, 'Disponible', 'Camila Rojas'),
('Salón Auditorio', 300, 400000.00, 'En mantenimiento', 'Andrés Silva'),
('Salón Jardín', 100, 180000.00, 'Disponible', 'Marcela Duarte');

-- Clientes
INSERT INTO clientes (nombre_completo, identificacion, telefono, correo_electronico, tipo_cliente) VALUES
('Constructora Andes S.A.S.', '900123456', '3111234567', 'eventos@andes.com', 'Corporativo'),
('Laura Martínez', '1098765432', '3129876543', 'laura.martinez@correo.com', 'Individual'),
('Grupo Financiero Sur', '900654321', '3151122334', 'contacto@gfsur.com', 'Corporativo'),
('Carlos Herrera', '1012345678', '3167788990', 'carlos.herrera@correo.com', 'Individual'),
('Tech Solutions S.A.S.', '900998877', '3178899001', 'rrhh@techsolutions.com', 'Corporativo');

-- Reservas
-- Nota: total_horas y valor_total quedan en 0 aquí porque el trigger
-- tr_calcular_totales_reserva (ver triggers.sql) los recalcula al insertar.
-- En este script se insertan con datos "placeholder" y triggers.sql
-- muestra el resultado real tras crear el trigger.
-- El Salón Auditorio (id 4) está "En mantenimiento" a propósito y NO se
-- reserva en los datos semilla: sirve para probar en views_and_queries.sql
-- que verificar_disponibilidad() lo rechace por su estado.
INSERT INTO reservas (fecha_inicio, fecha_fin, id_cliente, id_salon, total_horas, valor_total) VALUES
('2026-09-05 08:00:00', '2026-09-05 12:00:00', 1, 1, 0, 0),
('2026-09-10 14:00:00', '2026-09-10 18:00:00', 3, 3, 0, 0),
('2026-09-15 09:00:00', '2026-09-15 17:00:00', 5, 5, 0, 0),
('2026-09-20 19:00:00', '2026-09-20 23:00:00', 2, 2, 0, 0),
('2026-10-01 10:00:00', '2026-10-01 13:00:00', 1, 1, 0, 0),
('2026-10-05 08:00:00', '2026-10-05 14:00:00', 3, 5, 0, 0),
-- Reservas extra para que Constructora Andes (cliente corporativo)
-- supere las 3 reservas y la consulta #3 tenga un resultado real que mostrar.
('2026-10-12 09:00:00', '2026-10-12 12:00:00', 1, 2, 0, 0),
('2026-10-20 16:00:00', '2026-10-20 20:00:00', 1, 5, 0, 0);

-- Pagos
INSERT INTO pagos (id_reserva, fecha_pago, monto_pagado, metodo_pago) VALUES
(1, '2026-09-01', 1190000.00, 'Transferencia'),
(2, '2026-09-06', 1428000.00, 'Tarjeta'),
(4, '2026-09-18', 714000.00, 'Efectivo');