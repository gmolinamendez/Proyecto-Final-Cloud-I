import os
import uuid

import boto3
from botocore.exceptions import ClientError

from common import audit, get_user_id, parse_body, response, require_role, today


dynamodb = boto3.resource("dynamodb")

STORE_TABLE = os.environ["STORE_TABLE"]
AUDIT_TABLE = os.environ.get("AUDIT_TABLE")

stores_table = dynamodb.Table(STORE_TABLE)
audit_table = dynamodb.Table(AUDIT_TABLE) if AUDIT_TABLE else None


def lambda_handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method")
    tienda_id = (event.get("pathParameters") or {}).get("tienda_id")

    if method == "OPTIONS":
        return response(204, {})
    if method == "POST" and not tienda_id:
        return create_store(event)
    if method == "GET" and tienda_id:
        return get_store(event, tienda_id)
    if method == "GET":
        return list_stores(event)
    if method == "PUT" and tienda_id:
        return update_store(event, tienda_id)
    if method == "DELETE" and tienda_id:
        return deactivate_store(event, tienda_id)
    return response(405, {"error": f"Metodo {method} no soportado"})


def create_store(event):
    allowed, error = require_role(event, ["Administrador"])
    if not allowed:
        return error

    body = parse_body(event)
    if body is None:
        return response(400, {"error": "JSON invalido"})

    nombre = body.get("nombre")
    if not nombre:
        return response(400, {"error": "nombre es requerido"})

    item = {
        "tienda_id": str(uuid.uuid4()),
        "nombre": nombre,
        "descripcion": body.get("descripcion", ""),
        "activo": True,
        "fecha_creacion": today(),
    }
    stores_table.put_item(Item=item)
    audit(audit_table, get_user_id(event), "CREAR_TIENDA", detalle=item["tienda_id"])
    return response(201, item)


def list_stores(event):
    allowed, error = require_role(event, ["Administrador", "Operador", "Cliente"])
    if not allowed:
        return error

    result = stores_table.scan()
    items = [item for item in result.get("Items", []) if item.get("activo", True)]
    return response(200, {"tiendas": items})


def get_store(event, tienda_id):
    allowed, error = require_role(event, ["Administrador", "Operador", "Cliente"])
    if not allowed:
        return error

    item = stores_table.get_item(Key={"tienda_id": tienda_id}).get("Item")
    if not item or item.get("activo") is False:
        return response(404, {"error": "Tienda no encontrada"})
    return response(200, item)


def update_store(event, tienda_id):
    allowed, error = require_role(event, ["Administrador"])
    if not allowed:
        return error

    body = parse_body(event)
    if body is None:
        return response(400, {"error": "JSON invalido"})

    updates = {}
    for field in ["nombre", "descripcion", "activo"]:
        if field in body:
            updates[field] = body[field]
    if not updates:
        return response(400, {"error": "No hay campos para actualizar"})

    try:
        result = _update_store_item(tienda_id, updates)
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return response(404, {"error": "Tienda no encontrada"})
        raise

    audit(audit_table, get_user_id(event), "ACTUALIZAR_TIENDA", detalle=tienda_id)
    return response(200, result["Attributes"])


def deactivate_store(event, tienda_id):
    allowed, error = require_role(event, ["Administrador"])
    if not allowed:
        return error

    try:
        _update_store_item(tienda_id, {"activo": False})
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return response(404, {"error": "Tienda no encontrada"})
        raise

    audit(audit_table, get_user_id(event), "DESACTIVAR_TIENDA", detalle=tienda_id)
    return response(200, {"message": "Tienda desactivada"})


def _update_store_item(tienda_id, updates):
    names = {}
    values = {}
    parts = []
    for index, (field, value) in enumerate(updates.items()):
        name_key = f"#f{index}"
        value_key = f":v{index}"
        names[name_key] = field
        values[value_key] = value
        parts.append(f"{name_key} = {value_key}")

    return stores_table.update_item(
        Key={"tienda_id": tienda_id},
        UpdateExpression="SET " + ", ".join(parts),
        ExpressionAttributeNames=names,
        ExpressionAttributeValues=values,
        ReturnValues="ALL_NEW",
        ConditionExpression="attribute_exists(tienda_id)",
    )
