-- Creación de la tabla Áreas
CREATE TABLE areas (
    area_id SERIAL PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL,
    es_fumadores BOOLEAN NOT NULL
);

-- Creación de la tabla Mesas
CREATE TABLE mesas (
    mesa_id SERIAL PRIMARY KEY,
    area_id INTEGER NOT NULL,
    capacidad INTEGER NOT NULL,
    es_móvil BOOLEAN NOT NULL,
    FOREIGN KEY (area_id) REFERENCES areas(area_id)
);

-- Creación de la tabla Usuarios (empleados)
CREATE TABLE usuarios (
    usuario_id SERIAL PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL,
    contraseña VARCHAR(255) NOT NULL,
    rol VARCHAR(100) NOT NULL
);

-- Creación de la tabla Pedidos
CREATE TABLE pedidos (
    pedido_id SERIAL PRIMARY KEY,
    mesa_id INTEGER NOT NULL,
    usuario_id INTEGER NOT NULL,
    fecha_hora TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_hora_cierre TIMESTAMP,
    estado VARCHAR(100) NOT NULL,
    FOREIGN KEY (mesa_id) REFERENCES mesas(mesa_id),
    FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
);

-- Creación de la tabla Platos y Bebidas
CREATE TABLE platos_bebidas (
    plato_bebida_id SERIAL PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(10, 2) NOT NULL,
    tipo VARCHAR(50) NOT NULL
);

-- Creación de la tabla Items del Pedido
CREATE TABLE items_pedido (
    item_pedido_id SERIAL PRIMARY KEY,
    pedido_id INTEGER NOT NULL,
    plato_bebida_id INTEGER NOT NULL,
    cantidad INTEGER NOT NULL,
    FOREIGN KEY (pedido_id) REFERENCES pedidos(pedido_id),
    FOREIGN KEY (plato_bebida_id) REFERENCES platos_bebidas(plato_bebida_id)
);

-- Creación de la tabla Clientes
CREATE TABLE clientes (
    cliente_id SERIAL PRIMARY KEY,
    nit VARCHAR(255),
    nombre VARCHAR(255) NOT NULL,
    direccion VARCHAR(255)
);

-- Creación de la tabla Pagos
CREATE TABLE pagos (
    pago_id SERIAL PRIMARY KEY,
    pedido_id INTEGER NOT NULL,
    monto DECIMAL(10, 2) NOT NULL,
    tipo VARCHAR(100) NOT NULL,
    FOREIGN KEY (pedido_id) REFERENCES pedidos(pedido_id)
);

-- Creación de la tabla Encuestas
CREATE TABLE encuestas (
    encuesta_id SERIAL PRIMARY KEY,
    pedido_id INTEGER NOT NULL,
    calificacion_amabilidad INTEGER CHECK (calificacion_amabilidad BETWEEN 1 AND 5),
    calificacion_exactitud INTEGER CHECK (calificacion_exactitud BETWEEN 1 AND 5),
    FOREIGN KEY (pedido_id) REFERENCES pedidos(pedido_id)
);

-- Creación de la tabla Quejas
CREATE TABLE quejas (
    queja_id SERIAL PRIMARY KEY,
    cliente_id INTEGER NOT NULL,
    fecha_hora TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    motivo VARCHAR(255) NOT NULL,
    clasificacion INTEGER CHECK (clasificacion BETWEEN 1 AND 5),
    FOREIGN KEY (cliente_id) REFERENCES clientes(cliente_id)
);

CREATE OR REPLACE FUNCTION encrypt_password()
RETURNS TRIGGER AS $$
BEGIN
    NEW.contraseña := crypt(NEW.contraseña, gen_salt('bf'));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para encriptar la contraseña antes de insertar un nuevo usuario
CREATE TRIGGER encrypt_before_insert BEFORE INSERT ON usuarios
FOR EACH ROW EXECUTE FUNCTION encrypt_password();

-- Procedimiento para verificar las credenciales de usuario y retornar también el rol y el ID
CREATE OR REPLACE FUNCTION verify_user(login_nombre VARCHAR, login_contraseña VARCHAR)
RETURNS TABLE(user_found BOOLEAN, user_id INT, user_role VARCHAR) AS $$
BEGIN
    RETURN QUERY 
    SELECT EXISTS(SELECT 1 FROM usuarios WHERE nombre = login_nombre AND contraseña = crypt(login_contraseña, contraseña)),
           (SELECT usuario_id FROM usuarios WHERE nombre = login_nombre AND contraseña = crypt(login_contraseña, contraseña) LIMIT 1),
           (SELECT rol FROM usuarios WHERE nombre = login_nombre AND contraseña = crypt(login_contraseña, contraseña) LIMIT 1);
END;
$$ LANGUAGE plpgsql;

-- Procedimiento para crear una nueva cuenta
CREATE OR REPLACE FUNCTION crear_cuenta(nombre_usuario VARCHAR, rol_usuario VARCHAR, password_usuario VARCHAR)
RETURNS BOOLEAN AS $$
BEGIN
    -- Insertar el nuevo usuario en la tabla 'usuarios'
    INSERT INTO usuarios (nombre, rol, contraseña)
    VALUES (nombre_usuario, rol_usuario, password_usuario);
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        -- Retornar FALSE en caso de cualquier error
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Procedimiento para ingresar un pedido
CREATE OR REPLACE FUNCTION tomar_pedido(mesa_id_param INT, usuario_id_param INT, detalles_pedido JSON)
RETURNS VOID AS $$
DECLARE
    local_pedido_id INT;  -- Renombrar la variable local para evitar ambigüedad
BEGIN
    -- Verificar si hay un pedido abierto para la mesa
    SELECT pedido_id INTO local_pedido_id
    FROM pedidos
    WHERE mesa_id = mesa_id_param AND estado = 'abierto' LIMIT 1;

    -- Si no existe un pedido abierto, crear uno nuevo
    IF local_pedido_id IS NULL THEN
        INSERT INTO pedidos (mesa_id, usuario_id, estado) 
        VALUES (mesa_id_param, usuario_id_param, 'abierto') 
        RETURNING pedido_id INTO local_pedido_id;  -- Usar la variable local renombrada
    END IF;

    -- Insertar los detalles del pedido
    FOR i IN 0 .. json_array_length(detalles_pedido) - 1 LOOP
        INSERT INTO items_pedido (pedido_id, plato_bebida_id, cantidad)
        VALUES (local_pedido_id, (detalles_pedido->i->>'plato_bebida_id')::INT, (detalles_pedido->i->>'cantidad')::INT);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Procedimiento para añadir un área
CREATE OR REPLACE FUNCTION add_area(nombre VARCHAR, es_fumadores BOOLEAN)
RETURNS VOID AS $$
BEGIN
    INSERT INTO areas (nombre, es_fumadores) VALUES (nombre, es_fumadores);
END;
$$ LANGUAGE plpgsql;

-- Procedimiento para añadir una mesa
CREATE OR REPLACE FUNCTION add_mesa(area_id INTEGER, capacidad INTEGER, es_móvil BOOLEAN)
RETURNS VOID AS $$
BEGIN
    INSERT INTO mesas (area_id, capacidad, es_móvil) VALUES (area_id, capacidad, es_móvil);
END;
$$ LANGUAGE plpgsql;

-- Procedimiento para añadir un plato o bebida
CREATE OR REPLACE FUNCTION add_plato_bebida(nombre VARCHAR, descripcion TEXT, precio DECIMAL, tipo VARCHAR)
RETURNS VOID AS $$
BEGIN
    INSERT INTO platos_bebidas (nombre, descripcion, precio, tipo) VALUES (nombre, descripcion, precio, tipo);
END;
$$ LANGUAGE plpgsql;

-- Procedimiento para mostrar los platillos pendientes
CREATE OR REPLACE FUNCTION mostrar_platillos_pendientes()
RETURNS TABLE(plato_bebida_id INT, nombre VARCHAR, cantidad INT, hora TIMESTAMP) AS $$
BEGIN
    RETURN QUERY
    SELECT pb.plato_bebida_id, pb.nombre, ip.cantidad, p.fecha_hora
    FROM pedidos p
    JOIN items_pedido ip ON p.pedido_id = ip.pedido_id
    JOIN platos_bebidas pb ON pb.plato_bebida_id = ip.plato_bebida_id
    WHERE pb.tipo = 'Plato' AND p.estado = 'abierto'
    ORDER BY p.fecha_hora;
END;
$$ LANGUAGE plpgsql;

-- Procedimiento para mostrar las bebidas pendientes
CREATE OR REPLACE FUNCTION mostrar_bebidas_pendientes()
RETURNS TABLE(plato_bebida_id INT, nombre VARCHAR, cantidad INT, hora TIMESTAMP) AS $$
BEGIN
    RETURN QUERY
    SELECT pb.plato_bebida_id, pb.nombre, ip.cantidad, p.fecha_hora
    FROM pedidos p
    JOIN items_pedido ip ON p.pedido_id = ip.pedido_id
    JOIN platos_bebidas pb ON pb.plato_bebida_id = ip.plato_bebida_id
    WHERE pb.tipo = 'Bebida' AND p.estado = 'abierto'
    ORDER BY p.fecha_hora;
END;
$$ LANGUAGE plpgsql;

-- Procedimiento para obtener los detalles de un pedido
CREATE OR REPLACE FUNCTION listar_pedidos_activos()
RETURNS TABLE(pedido_id INT, fecha_hora TIMESTAMP, estado VARCHAR) AS $$
BEGIN
    RETURN QUERY 
    SELECT pedidos.pedido_id, pedidos.fecha_hora, pedidos.estado
    FROM pedidos
    WHERE pedidos.estado = 'abierto'
    ORDER BY pedidos.fecha_hora DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION obtener_detalles_pedido(pedido_id_param INT)
RETURNS TABLE(producto VARCHAR, cantidad INT, precio_unitario DECIMAL, subtotal DECIMAL) AS $$
BEGIN
    RETURN QUERY 
    SELECT pb.nombre, ip.cantidad, pb.precio, (ip.cantidad * pb.precio) AS subtotal
    FROM items_pedido ip
    JOIN platos_bebidas pb ON ip.plato_bebida_id = pb.plato_bebida_id
    WHERE ip.pedido_id = pedido_id_param;
END;
$$ LANGUAGE plpgsql;

-- Procedimiento para cerrar un pedido
CREATE OR REPLACE FUNCTION cerrar_pedido(pedido_id_param INT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE pedidos
    SET estado = 'cerrado', fecha_hora_cierre = NOW()
    WHERE pedido_id = pedido_id_param AND estado = 'abierto';
    
    IF FOUND THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Insertar datos de prueba
SELECT add_area('Terraza', FALSE);
SELECT add_area('Bar Interior', FALSE);
SELECT add_area('Zona de Fumadores', TRUE);
SELECT add_area('Salón Privado', FALSE);

SELECT add_mesa(1, 4, TRUE);
SELECT add_mesa(1, 2, TRUE);
SELECT add_mesa(2, 6, FALSE);
SELECT add_mesa(3, 4, TRUE);
SELECT add_mesa(4, 8, TRUE);

SELECT add_plato_bebida('Hamburguesa con Queso', 'Hamburguesa de carne de res con queso cheddar, lechuga, tomate y salsa especial', 8.50, 'Plato');
SELECT add_plato_bebida('Espagueti a la Boloñesa', 'Espagueti servido con una rica salsa boloñesa casera', 12.00, 'Plato');
SELECT add_plato_bebida('Margarita', 'Cóctel clásico con tequila, triple sec y jugo de lima', 7.00, 'Bebida');
SELECT add_plato_bebida('Jugo de Naranja Natural', 'Jugo recién exprimido de naranjas seleccionadas', 4.00, 'Bebida');
