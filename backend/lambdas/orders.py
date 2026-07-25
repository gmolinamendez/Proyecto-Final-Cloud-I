import json
import os
import uuid
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

from common import (
    audit,
    get_user_email,
    get_user_id,
    has_role,
    parse_body,
    response,
    require_role,
    to_jsonable,
    today,
)


dynamodb = boto3.resource("dynamodb")
events = boto3.client("events")

ORDER_TABLE = os.environ["ORDER_TABLE"]
PRODUCT_TABLE = os.environ["PRODUCT_TABLE"]
AUDIT_TABLE = os.environ.get("AUDIT_TABLE")
EVENT_BUS_NAME = os.environ["EVENT_BUS_NAME"]

orders_table = dynamodb.Table(ORDER_TABLE)
products_table = dynamodb.Table(PRODUCT_TABLE)
audit_table = dynamodb.Table(AUDIT_TABLE) if AUDIT_TABLE else None

VALID_STATES = [
    "Pendiente",
    "Confirmado",
    "En preparacion",
    "Enviado",
    "Entregado",
    "Cancelado",
]
CANCELABLE_STATES = {"Pendiente", "Confirmado", "En preparacion"}


def lambda_handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method")
    path_params = event.get("pathParameters") or {}
    pedido_id = path_params.get("pedido_id")
    raw_path = event.get("rawPath", "")

    if method == "OPTIONS":
        return response(204, {})
    if method == "POST" and not pedido_id:
        return create_order(event)
    if method == "GET" and pedido_id:
        return get_order(event, pedido_id)
    if method == "GET":
        return list_orders(event)
    if method == "PUT" and pedido_id and raw_path.endswith("/estado"):
        return update_order_status(event, pedido_id)
    if method == "DELETE" and pedido_id:
        return cancel_order(event, pedido_id)
    return response(405, {"error": f"Metodo {method} no soportado"})


def create_order(event):
    allowed, error = require_role(event, ["Administrador", "Cliente"])
    if not allowed:
        return error

    body = parse_body(event)
    if body is None:
        return response(400, {"error": "JSON invalido"})

    items = body.get("items", [])
    if not items:
        return response(400, {"error": "items es requerido"})

    pedido_items = []
    total = Decimal("0")
    for item in items:
        producto_id = item.get("producto_id")
        cantidad = int(item.get("cantidad", 0))
        if not producto_id or cantidad <= 0:
            return response(400, {"error": "Cada item requiere producto_id y cantidad > 0"})

        product = products_table.get_item(Key={"producto_id": producto_id}).get("Item")
        if not product or product.get("activo") is False:
            return response(400, {"error": f"Producto no disponible: {producto_id}"})
        if "precio" not in product or "inventario" not in product:
            return response(400, {"error": f"Producto incompleto: {producto_id}"})
        if int(product.get("inventario", 0)) < cantidad:
            return response(400, {"error": f"Inventario insuficiente: {producto_id}"})

        precio = Decimal(str(product["precio"]))
        subtotal = precio * cantidad
        total += subtotal
        pedido_items.append(
            {
                "producto_id": producto_id,
                "nombre": product.get("nombre"),
                "tienda_id": product.get("tienda_id"),
                "cantidad": cantidad,
                "precio_unitario": precio,
                "subtotal": subtotal,
            }
        )

    pedido_id = str(uuid.uuid4())
    usuario_id = get_user_id(event)
    item = {
        "pedido_id": pedido_id,
        "usuario_id": usuario_id,
        "usuario_email": get_user_email(event),
        "items": pedido_items,
        "total": total,
        "estado": "Pendiente",
        "fecha": today(),
        "requiere_revision": False,
    }
    orders_table.put_item(Item=item)

    event_detail = {
        "pedido_id": pedido_id,
        "usuario_id": usuario_id,
        "usuario_email": item["usuario_email"],
        "items": pedido_items,
        "total": total,
    }
    result = events.put_events(
        Entries=[
            {
                "EventBusName": EVENT_BUS_NAME,
                "Source": "cloudshop.orders",
                "DetailType": "Pedido Creado",
                "Detail": json.dumps(to_jsonable(event_detail), ensure_ascii=False),
            }
        ]
    )
    event_ok = result.get("FailedEntryCount", 0) == 0
    audit(audit_table, usuario_id, "CREAR_PEDIDO", "EXITOSO" if event_ok else "FALLIDO", pedido_id)
    return response(201, {**item, "evento_generado": event_ok})


def list_orders(event):
    allowed, error = require_role(event, ["Administrador", "Operador", "Cliente"])
    if not allowed:
        return error

    if has_role(event, ["Administrador", "Operador"]):
        result = orders_table.scan()
    else:
        result = orders_table.query(
            IndexName="usuario-index",
            KeyConditionExpression=Key("usuario_id").eq(get_user_id(event)),
        )
    return response(200, {"pedidos": result.get("Items", [])})


def get_order(event, pedido_id):
    allowed, error = require_role(event, ["Administrador", "Operador", "Cliente"])
    if not allowed:
        return error

    item = orders_table.get_item(Key={"pedido_id": pedido_id}).get("Item")
    if not item:
        return response(404, {"error": "Pedido no encontrado"})
    if not has_role(event, ["Administrador", "Operador"]) and item.get("usuario_id") != get_user_id(event):
        return response(403, {"error": "Forbidden"})
    return response(200, item)


def update_order_status(event, pedido_id):
    allowed, error = require_role(event, ["Administrador", "Operador"])
    if not allowed:
        return error

    body = parse_body(event)
    if body is None:
        return response(400, {"error": "JSON invalido"})
    estado = body.get("estado")
    if estado not in VALID_STATES:
        return response(400, {"error": "Estado invalido", "validos": VALID_STATES})

    try:
        result = orders_table.update_item(
            Key={"pedido_id": pedido_id},
            UpdateExpression="SET estado = :estado",
            ExpressionAttributeValues={":estado": estado},
            ConditionExpression="attribute_exists(pedido_id)",
            ReturnValues="ALL_NEW",
        )
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return response(404, {"error": "Pedido no encontrado"})
        raise

    audit(audit_table, get_user_id(event), "ACTUALIZAR_ESTADO_PEDIDO", detalle=pedido_id)
    return response(200, result["Attributes"])


def cancel_order(event, pedido_id):
    item = orders_table.get_item(Key={"pedido_id": pedido_id}).get("Item")
    if not item:
        return response(404, {"error": "Pedido no encontrado"})

    if not has_role(event, ["Administrador", "Operador"]) and item.get("usuario_id") != get_user_id(event):
        return response(403, {"error": "Forbidden"})
    if item.get("estado") not in CANCELABLE_STATES:
        return response(400, {"error": "El pedido ya no se puede cancelar"})

    result = orders_table.update_item(
        Key={"pedido_id": pedido_id},
        UpdateExpression="SET estado = :estado",
        ExpressionAttributeValues={":estado": "Cancelado"},
        ReturnValues="ALL_NEW",
    )
    audit(audit_table, get_user_id(event), "CANCELAR_PEDIDO", detalle=pedido_id)
    return response(200, result["Attributes"])
