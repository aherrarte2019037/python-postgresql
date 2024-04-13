from getpass import getpass
import os
from user_interface import role_menu
from database import get_connection, create_account_db, login_db

# Función para iniciar sesión utilizando el procedimiento almacenado
def login():
    clear_console()
    username = input("Nombre de usuario: ")
    password = getpass("Contraseña: ")
    return login_db(username, password)

def create_account():
    clear_console()
    username = input("Ingrese el nombre de usuario: ")
    role = input("Ingrese el rol del usuario (solo 'admin' o 'mesero' son permitidos): ").lower()
    password = getpass("Ingrese su contraseña: ")
    create_account_db(username, role, password)

# Función para limpiar la consola
def clear_console():
    if os.name == 'nt':  # para Windows
        os.system('cls')
    else:  # para Unix/Linux/Mac
        os.system('clear')

# Menú principal de la aplicación
def main_menu():
    while True:
        print("\n--- Menú Principal ---")
        print("1. Crear cuenta")
        print("2. Iniciar sesión")
        print("3. Salir")
        choice = input("Seleccione una opción: ")

        if choice == '1':
            create_account()
            
        elif choice == '2':
            success, user_id, role = login()
            if success:
                role_menu(user_id, role)
        elif choice == '3':
            clear_console()
            print("Saliendo...")
            break
        else:
            clear_console()
            print("Opción no válida. Por favor, intente de nuevo.")

if __name__ == "__main__":
    main_menu()
