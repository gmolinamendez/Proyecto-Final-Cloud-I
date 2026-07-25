import os
from collections import Counter, defaultdict
from decimal import Decimal

import boto3

from common import response, require_role


dynamodb = boto3.resource("dynamodb")

ORDER_TABLE = os.environ["ORDER_TABLE"]
PRODUCT_TABLE = os.environ["PRODUCT_TABLE"]
USER_TABLE = os.environ["USER_TABLE"]

orders_table = dynamodb.Table(ORDER_TABLE)
products_table = dynamodb.Table(PRODUCT_TABLE)
users_table = dynamodb.Table(USER_TABLE)


def lambda_handler(event, context):
    allowed, error = require_role(event, ["Administrador"])
    if not allowed:
        return error

    orders = orders_table.scan().get("Items", [])
    products = products_table.scan().get("Items", [])
    users = users_table.scan().get("Items", [])

    active_sales = [order for order in orders if order.get("estado") != "Cancelado"]
    total_ventas = sum(Decimal(str(order.get("total", 0))) for order in active_sales)

    ventas_por_tienda = defaultdict(Decimal)
    productos_vendidos = Counter()
    clientes_compras = Counter()
    pedidos_por_estado = Counter()
    user_names = {user["usuario_id"]: user.get("nombre", user.get("email")) for user in users}
    product_names = {product["producto_id"]: product.get("nombre") for product in products}

    for order in orders:
        pedidos_por_estado[order.get("estado", "Sin estado")] += 1
        if order.get("estado") == "Cancelado":
            continue
        clientes_compras[order.get("usuario_id", "desconocido")] += 1
        for item in order.get("items", []):
            tienda_id = item.get("tienda_id", "sin tienda")
            producto_id = item.get("producto_id")
            subtotal = Decimal(str(item.get("subtotal", 0)))
            cantidad = int(item.get("cantidad", 0))
            ventas_por_tienda[tienda_id] += subtotal
            productos_vendidos[producto_id] += cantidad

    productos_agotados = [
        {
            "producto_id": product["producto_id"],
            "nombre": product.get("nombre"),
            "inventario": product.get("inventario", 0),
        }
        for product in products
        if int(product.get("inventario", 0)) <= 0 and product.get("activo", True)
    ]

    data = {
        "total_ventas": total_ventas,
        "ventas_por_tienda": [
            {"tienda_id": tienda_id, "total": total}
            for tienda_id, total in sorted(ventas_por_tienda.items(), key=lambda item: item[1], reverse=True)
        ],
        "productos_mas_vendidos": [
            {
                "producto_id": producto_id,
                "nombre": product_names.get(producto_id),
                "cantidad": cantidad,
            }
            for producto_id, cantidad in productos_vendidos.most_common(5)
        ],
        "productos_agotados": productos_agotados,
        "clientes_con_mas_compras": [
            {
                "usuario_id": usuario_id,
                "nombre": user_names.get(usuario_id),
                "compras": compras,
            }
            for usuario_id, compras in clientes_compras.most_common(5)
        ],
        "pedidos_por_estado": [
            {"estado": estado, "cantidad": cantidad}
            for estado, cantidad in pedidos_por_estado.items()
        ],
    }
    return response(200, data)
