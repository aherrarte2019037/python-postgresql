import os
from database import take_order_db

def role_menu(user_id, role):
    print(f"--- Menú {role.capitalize()} ---")
    if role == 'admin':
        print("1. Gestionar usuarios")
        print("2. Ver reportes")
        print("3. Configuraciones del sistema")
    elif role == 'mesero':
        print("1. Tomar pedido")
        print("2. Ver pedidos activos")
        print("3. Cerrar cuenta de mesa")
    print("4. Salir")

    choice = input("Seleccione una opción: ")
    if choice == '1' and role == 'mesero':
        take_order(user_id)
    elif choice == '4':
        clear_console()
        return
    else:
        print("Funcionalidad aún no implementada.")
        input("Presione Enter para continuar...")

def take_order(usuario_id):
    clear_console()
    print("--- Tomar Pedido ---")
    mesa_id = input("Ingrese el número de mesa: ")
    try:
        mesa_id = int(mesa_id)
    except ValueError:
        print("Número de mesa no válido.")
        return

    orders = []
    while True:
        dish_id = input("Ingrese el ID del plato o bebida: ")
        if not dish_id:
            break
        quantity = input(f"Ingrese la cantidad de plato/bebida ID {dish_id}: ")
        try:
            dish_id = int(dish_id)
            quantity = int(quantity)
            orders.append({"plato_bebida_id": dish_id, "cantidad": quantity})
        except ValueError:
            print("Entrada no válida, por favor ingrese números válidos.")
            continue
        more = input("¿Agregar más platos/bebidas? (s/n): ")
        if more.lower() != 's':
            break

    if orders:
        if take_order_db(mesa_id, usuario_id, orders):
            print("Pedido realizado exitosamente.")
        else:
            print("No se pudo realizar el pedido.")
    input("Presione Enter para continuar...")

# Función auxiliar para limpiar la consola
def clear_console():
    if os.name == 'nt':  # Para sistemas operativos Windows
        os.system('cls')
    else:  # Para Unix/Linux/Mac
        os.system('clear')
