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
    estado VARCHAR(100) NOT NULL,
    FOREIGN KEY (mesa_id) REFERENCES mesas(mesa_id),
    FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
);

-- Creación de la tabla Platos y Bebidas
CREATE TABLE platos_bebidas (
    plato_bebida_id SERIAL PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(10, 2) NOT NULL
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
CREATE OR REPLACE FUNCTION tomar_pedido(mesa_id INT, usuario_id INT, detalles_pedido JSON)
RETURNS VOID AS $$
DECLARE
    pedido_id INT;
BEGIN
    -- Verificar si hay un pedido abierto para la mesa
    SELECT pedido_id INTO pedido_id FROM pedidos WHERE mesa_id = mesa_id AND estado = 'abierto' LIMIT 1;

    -- Si no existe un pedido abierto, crear uno nuevo
    IF pedido_id IS NULL THEN
        INSERT INTO pedidos (mesa_id, usuario_id, estado) VALUES (mesa_id, usuario_id, 'abierto') RETURNING pedido_id INTO pedido_id;
    END IF;

    -- Insertar los detalles del pedido
    FOR i IN 0 .. json_array_length(detalles_pedido) - 1 LOOP
        INSERT INTO items_pedido (pedido_id, plato_bebida_id, cantidad)
        VALUES (pedido_id, (detalles_pedido->i->>'plato_bebida_id')::INT, (detalles_pedido->i->>'cantidad')::INT);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Trigger para registrar cada pedido cerrado
CREATE OR REPLACE FUNCTION log_pedido_cerrado()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO log_pedidos (pedido_id, fecha_hora_cierre) VALUES (NEW.pedido_id, NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_after_close AFTER UPDATE ON pedidos
FOR EACH ROW WHEN (NEW.estado = 'cerrado')
EXECUTE FUNCTION log_pedido_cerrado();
