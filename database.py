import psycopg2
import os
import json

# Se define la URL de la conexión a la base de datos
DATABASE_URL = "postgres://mjrpzdyy:6foY-FOw2jzKTWHFcLpNZmAiuRVz23gd@bubble.db.elephantsql.com/mjrpzdyy"

# Función para obtener una conexión a la base de datos
def get_connection():
    return psycopg2.connect(DATABASE_URL)

# Función para crear una cuenta de usuario utilizando el procedimiento almacenado en PostgreSQL
def create_account_db(username, role, password):    
    # Validación del rol del usuario
    if role not in ['admin', 'mesero']:
        clear_console()
        print("Rol no válido. Por favor, elija 'admin' o 'mesero'.")
        return False

    # Intentar conectar con la base de datos y ejecutar la creación de la cuenta
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                # Llamar al procedimiento almacenado para crear la cuenta
                cur.callproc('crear_cuenta', [username, role, password])
                result = cur.fetchone()[0]
                conn.commit()
                
        if result:
            clear_console()
            print("Usuario creado exitosamente.")
            return True
        else:
            clear_console()
            print("No se pudo crear el usuario.")
            return False
    except Exception as e:
        clear_console()
        print(f"Error al crear usuario: {e}")
        return False

# Función para iniciar sesión utilizando el procedimiento almacenado
def login_db(username, password):
    clear_console()
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                # Llamada al procedimiento almacenado
                cur.callproc('verify_user', [username, password])
                user_info = cur.fetchone()
                
        if user_info and user_info[0]:
            # Retorna un valor booleano para éxito, el ID del usuario y el rol
            return True, user_info[1], user_info[2]
        else:
            print("Nombre de usuario o contraseña incorrecta.")
            return False, None, None
    except Exception as e:
        print(f"Error al iniciar sesión: {e}")
        return False, None, None

# Función para tomar un pedido utilizando el procedimiento almacenado
def take_order_db(mesa_id, usuario_id, detalles_pedido):
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                # Convertir detalles_pedido a JSON
                detalles_pedido_json = json.dumps(detalles_pedido)
                # Llamar al procedimiento almacenado
                cur.callproc('tomar_pedido', [mesa_id, usuario_id, detalles_pedido_json])
                conn.commit()
                print("Pedido ingresado exitosamente.")
                return True
    except Exception as e:
        print(f"Error al tomar el pedido: {e}")
        return False

# Función auxiliar para limpiar la consola
def clear_console():
    if os.name == 'nt':  # Para sistemas operativos Windows
        os.system('cls')
    else:  # Para Unix/Linux/Mac
        os.system('clear')
