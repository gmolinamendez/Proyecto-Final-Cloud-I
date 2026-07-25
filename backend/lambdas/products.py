import os
import uuid
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

from common import audit, get_user_id, parse_body, response, require_role, today


dynamodb = boto3.resource("dynamodb")

PRODUCT_TABLE = os.environ["PRODUCT_TABLE"]
STORE_TABLE = os.environ["STORE_TABLE"]
AUDIT_TABLE = os.environ.get("AUDIT_TABLE")

products_table = dynamodb.Table(PRODUCT_TABLE)
stores_table = dynamodb.Table(STORE_TABLE)
audit_table = dynamodb.Table(AUDIT_TABLE) if AUDIT_TABLE else None


def lambda_handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method")
    producto_id = (event.get("pathParameters") or {}).get("producto_id")

    if method == "OPTIONS":
        return response(204, {})
    if method == "POST" and not producto_id:
        return create_product(event)
    if method == "GET" and producto_id:
        return get_product(event, producto_id)
    if method == "GET":
        return list_products(event)
    if method == "PUT" and producto_id:
        return update_product(event, producto_id)
    if method == "DELETE" and producto_id:
        return deactivate_product(event, producto_id)
    return response(405, {"error": f"Metodo {method} no soportado"})


def create_product(event):
    allowed, error = require_role(event, ["Administrador"])
    if not allowed:
        return error

    body = parse_body(event)
    if body is None:
        return response(400, {"error": "JSON invalido"})

    required = ["codigo", "nombre", "descripcion", "categoria", "precio", "inventario", "tienda_id"]
    missing = [field for field in required if field not in body]
    if missing:
        return response(400, {"error": "Campos requeridos faltantes", "fields": missing})

    store = stores_table.get_item(Key={"tienda_id": body["tienda_id"]}).get("Item")
    if not store or store.get("activo") is False:
        return response(400, {"error": "tienda_id no existe o esta inactiva"})

    item = {
        "producto_id": str(uuid.uuid4()),
        "codigo": str(body["codigo"]),
        "nombre": body["nombre"],
        "descripcion": body["descripcion"],
        "categoria": body["categoria"],
        "precio": Decimal(str(body["precio"])),
        "inventario": int(body["inventario"]),
        "tienda_id": body["tienda_id"],
        "activo": True,
        "fecha_creacion": today(),
        "vendidos": 0,
    }
    if item["precio"] < 0 or item["inventario"] < 0:
        return response(400, {"error": "precio e inventario deben ser positivos"})

    products_table.put_item(Item=item)
    audit(audit_table, get_user_id(event), "CREAR_PRODUCTO", detalle=item["producto_id"])
    return response(201, item)


def list_products(event):
    allowed, error = require_role(event, ["Administrador", "Operador", "Cliente"])
    if not allowed:
        return error

    query = event.get("queryStringParameters") or {}
    tienda_id = query.get("tienda_id")
    if tienda_id:
        result = products_table.query(
            IndexName="tienda-index",
            KeyConditionExpression=Key("tienda_id").eq(tienda_id),
        )
    else:
        result = products_table.scan()
    items = [
        item
        for item in result.get("Items", [])
        if item.get("activo", True)
        and "precio" in item
        and "inventario" in item
        and "nombre" in item
    ]
    return response(200, {"productos": items})


def get_product(event, producto_id):
    allowed, error = require_role(event, ["Administrador", "Operador", "Cliente"])
    if not allowed:
        return error

    item = products_table.get_item(Key={"producto_id": producto_id}).get("Item")
    if not item or item.get("activo") is False:
        return response(404, {"error": "Producto no encontrado"})
    return response(200, item)


def update_product(event, producto_id):
    body = parse_body(event)
    if body is None:
        return response(400, {"error": "JSON invalido"})

    admin_allowed, _ = require_role(event, ["Administrador"])
    operator_allowed, operator_error = require_role(event, ["Operador"])

    if admin_allowed:
        allowed_fields = ["codigo", "nombre", "descripcion", "categoria", "precio", "inventario", "tienda_id", "activo"]
    elif operator_allowed:
        allowed_fields = ["inventario"]
        blocked = [field for field in body if field not in allowed_fields]
        if blocked:
            return response(403, {"error": "Operador solo puede modificar inventario"})
    else:
        return operator_error

    updates = {field: body[field] for field in allowed_fields if field in body}
    if not updates:
        return response(400, {"error": "No hay campos para actualizar"})
    if "precio" in updates:
        updates["precio"] = Decimal(str(updates["precio"]))
    if "inventario" in updates:
        updates["inventario"] = int(updates["inventario"])
    if updates.get("precio", 0) < 0 or updates.get("inventario", 0) < 0:
        return response(400, {"error": "precio e inventario deben ser positivos"})

    try:
        result = _update_product_item(producto_id, updates)
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return response(404, {"error": "Producto no encontrado"})
        raise

    audit(audit_table, get_user_id(event), "ACTUALIZAR_PRODUCTO", detalle=producto_id)
    return response(200, result["Attributes"])


def deactivate_product(event, producto_id):
    allowed, error = require_role(event, ["Administrador"])
    if not allowed:
        return error

    try:
        _update_product_item(producto_id, {"activo": False})
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return response(404, {"error": "Producto no encontrado"})
        raise

    audit(audit_table, get_user_id(event), "ELIMINAR_PRODUCTO", detalle=producto_id)
    return response(200, {"message": "Producto desactivado"})


def _update_product_item(producto_id, updates):
    names = {}
    values = {}
    parts = []
    for index, (field, value) in enumerate(updates.items()):
        name_key = f"#f{index}"
        value_key = f":v{index}"
        names[name_key] = field
        values[value_key] = value
        parts.append(f"{name_key} = {value_key}")

    return products_table.update_item(
        Key={"producto_id": producto_id},
        UpdateExpression="SET " + ", ".join(parts),
        ExpressionAttributeNames=names,
        ExpressionAttributeValues=values,
        ReturnValues="ALL_NEW",
        ConditionExpression="attribute_exists(producto_id)",
    )
