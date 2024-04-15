import os
from database import execute_query, get_connection, take_order_db
from decimal import Decimal

def role_menu(user_id, role):
    while True:
        print(f"--- Menú {role.capitalize()} ---")
        if role == 'admin':
            print("1. Gestionar usuarios")
            print("2. Ver reportes")
            print("3. Configuraciones del sistema")
        elif role == 'mesero':
            print("1. Tomar pedido")
            print("2. Pantalla de Cocina")
            print("3. Pantalla de Bar")
            print("4. Imprimir pedido")
            print("5. Generar factura")
        print("6. Salir")

        choice = input("Seleccione una opción: ")
        if choice == '1' and role == 'mesero':
            take_order(user_id)
        elif choice == '2' and role == 'mesero':
            kitchen_screen()
        elif choice == '3' and role == 'mesero':
            bar_screen()
        elif choice == '4' and role == 'mesero':
            select_and_show_order_details()
        elif choice == '5' and role == 'mesero':
            generate_bill()
        elif choice == '6':
            clear_console()
            return
        else:
            print("Funcionalidad aún no implementada.")
            input("Presione Enter para continuar...")

def take_order(usuario_id):
    clear_console()
    tables = show_tables()
    if not tables:
        input("Presione Enter para regresar...")
        return

    mesa_id = input("Seleccione el número de mesa de la lista: ")
    try:
        mesa_id = int(mesa_id)
    except ValueError:
        print("Entrada no válida, por favor seleccione un número de la lista.")
        return

    dishes = show_dishes_and_beverages()
    if not dishes:
        input("Presione Enter para regresar...")
        return

    orders = []
    while True:
        dish_id = input("Seleccione el número del plato/bebida de la lista: ")
        if not dish_id:
            break
        quantity = input(f"Ingrese la cantidad: ")
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

    clear_console()

    if orders:
        if take_order_db(mesa_id, usuario_id, orders):
            print("Pedido ingresado exitosamente.")
        else:
            print("No se pudo realizar el pedido.")
    input("Presione Enter para continuar...")

def show_tables():
    clear_console()
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT mesa_id, capacidad FROM mesas ORDER BY mesa_id")
                tables = cur.fetchall()
                if tables:
                    print("Mesas disponibles:")
                    for table in tables:
                        print(f"[{table[0]}] Mesa, Capacidad: {table[1]} personas")
                    return tables
                else:
                    print("No hay mesas disponibles.")
                    return None
    except Exception as e:
        print(f"Error al obtener las mesas: {e}")
        return None

def show_dishes_and_beverages():
    clear_console()
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT plato_bebida_id, nombre, precio FROM platos_bebidas ORDER BY plato_bebida_id")
                dishes = cur.fetchall()
                if dishes:
                    print("Platos y Bebidas disponibles:")
                    for dish in dishes:
                        print(f"[{dish[0]}] {dish[1]}, Precio: ${dish[2]}")
                    return dishes
                else:
                    print("No hay platos o bebidas disponibles.")
                    return None
    except Exception as e:
        print(f"Error al obtener platos y bebidas: {e}")
        return None

def kitchen_screen():
    clear_console()
    print("--- Pantalla de Cocina ---")
    try:
        dishes = execute_query("SELECT * FROM mostrar_platillos_pendientes();")
        if dishes:
            for dish in dishes:
                print(f"Id: {dish[0]}, Nombre: {dish[1]}, Cantidad: {dish[2]}, Hora de Pedido: {dish[3]}")
        else:
            print("No hay platillos pendientes.")
    except Exception as e:
        print(f"Error al recuperar los platillos: {e}")
    
    input("\nPresione Enter para continuar...")
    clear_console()

def bar_screen():
    clear_console()
    print("--- Pantalla de Bar ---")
    try:
        beverages = execute_query("SELECT * FROM mostrar_bebidas_pendientes();")
        if beverages:
            for beverage in beverages:
                print(f"Id: {beverage[0]}, Nombre: {beverage[1]}, Cantidad: {beverage[2]}, Hora de Pedido: {beverage[3]}")
        else:
            print("No hay bebidas pendientes.")
    except Exception as e:
        print(f"Error al recuperar las bebidas: {e}")
    input("\nPresione Enter para continuar...")
    clear_console()

def list_active_orders():
    print("--- Pedidos Activos ---")
    try:
        active_orders = execute_query("SELECT * FROM listar_pedidos_activos();")
        if active_orders:
            for order in active_orders:
                print(f"[{order[0]}] Pedido, Fecha/Hora: {order[1]}")
            return active_orders
        else:
            print("No hay pedidos activos.")
            return None
    except Exception as e:
        print(f"Error al listar pedidos activos: {e}")
        return None

def select_and_show_order_details():
    clear_console()
    orders = list_active_orders()
    if not orders:
        input("Presione Enter para continuar...")
        clear_console()
        return
    
    pedido_id = input("\nIngrese el pedido que desea ver: ")
    try:
        pedido_id = int(pedido_id)
        show_order_details(pedido_id)
    except ValueError:
        print("Por favor, ingrese un número válido.")
    except Exception as e:
        print(f"Error al mostrar detalles del pedido: {e}")

    input("Presione Enter para continuar...")
    clear_console()

def show_order_details(pedido_id):
    clear_console()
    print("--- Detalles del Pedido ---")
    try:
        order_details = execute_query(f"SELECT * FROM obtener_detalles_pedido({pedido_id});")
        if order_details:
            total = 0
            print(f"Pedido: {pedido_id}")
            print("{:<30} {:<10} {:<15} {:<10}".format("Producto", "Cantidad", "Precio Unit.", "Subtotal"))
            for detail in order_details:
                print("{:<30} {:<10} ${:<14.2f} ${:<10.2f}".format(detail[0], detail[1], detail[2], detail[3]))
                total += detail[3]
            print(f"Total del Pedido: ${total:.2f}")
        else:
            print("No hay detalles disponibles para este pedido.")
    except Exception as e:
        print(f"Error al recuperar detalles del pedido: {e}")

def generate_bill():
    clear_console()
    orders = list_active_orders()
    if not orders:
        input("Presione Enter para continuar...")
        return

    pedido_id = input("\nIngrese el pedido para cerrar: ")
    try:
        pedido_id = int(pedido_id)
        if close_order(pedido_id):
            clear_console()
            print("Pedido cerrado correctamente.")
            print("\nMétodos de pago:")
            print("1. Efectivo")
            print("2. Tarjeta")
            print("3. Cheque")
            choice = input("Seleccione método de pago: ")
            payment_methods = { '1': 'Efectivo', '2': 'Tarjeta', '3': 'Cheque' }
            payment_method = payment_methods.get(choice, 'Efectivo')
            
            bill_details = execute_query(f"SELECT * FROM obtener_detalles_pedido({pedido_id});")
            clear_console()
            print("Detalle de la Factura:")
            total = Decimal('0.00')
            print("{:<30} {:<10} {:<15} {:<10}".format("Producto", "Cantidad", "Precio Unit.", "Subtotal"))
            for item in bill_details:
                subtotal = Decimal(item[1]) * Decimal(item[2])
                print("{:<30} {:<10} ${:<14.2f} ${:<10.2f}".format(item[0], item[1], item[2], subtotal))
                total += subtotal
            propina = total * Decimal('0.10')
            total_final = total + propina
            print("\nSubtotal: ${:.2f}".format(total))
            print("Propina (10%): ${:.2f}".format(propina))
            print("Total: ${:.2f}".format(total_final))
            print("Método de Pago: {}".format(payment_method))

            if execute_query(f"SELECT insertar_pago({pedido_id}, {total_final}, '{payment_method}');")[0][0]:
                print("Pago registrado correctamente.")
            else:
                print("Error al registrar el pago.")
        else:
            print("No se pudo cerrar el pedido. Asegúrese de que el ID sea correcto y el pedido esté abierto.")
    except ValueError:
        print("Por favor, ingrese un número válido.")
    except Exception as e:
        print(f"Error al cerrar pedido: {e}")

    input("Presione Enter para continuar...")
    clear_console()


def close_order(pedido_id):
    result = execute_query(f"SELECT cerrar_pedido({pedido_id});")
    return result[0][0] if result else False

# Función auxiliar para limpiar la consola
def clear_console():
    if os.name == 'nt':  # Para sistemas operativos Windows
        os.system('cls')
    else:  # Para Unix/Linux/Mac
        os.system('clear')
