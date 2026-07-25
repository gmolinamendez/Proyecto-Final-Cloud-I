import os
import uuid

import boto3
from botocore.exceptions import ClientError

from common import ROLES, audit, get_user_id, parse_body, response, require_role, today


dynamodb = boto3.resource("dynamodb")
cognito = boto3.client("cognito-idp")

USER_TABLE = os.environ["USER_TABLE"]
USER_POOL_ID = os.environ["USER_POOL_ID"]
AUDIT_TABLE = os.environ.get("AUDIT_TABLE")

users_table = dynamodb.Table(USER_TABLE)
audit_table = dynamodb.Table(AUDIT_TABLE) if AUDIT_TABLE else None


def lambda_handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method")
    path_params = event.get("pathParameters") or {}
    usuario_id = path_params.get("usuario_id")

    if method == "OPTIONS":
        return response(204, {})
    if method == "POST" and not usuario_id:
        return create_user(event)
    if method == "GET" and usuario_id:
        return get_user(event, usuario_id)
    if method == "GET":
        return list_users(event)
    if method == "PUT" and usuario_id:
        return update_user(event, usuario_id)
    if method == "DELETE" and usuario_id:
        return deactivate_user(event, usuario_id)
    return response(405, {"error": f"Metodo {method} no soportado"})


def create_user(event):
    allowed, error = require_role(event, ["Administrador"])
    if not allowed:
        return error

    body = parse_body(event)
    if body is None:
        return response(400, {"error": "JSON invalido"})

    email = body.get("email")
    nombre = body.get("nombre")
    rol = body.get("rol", "Cliente")
    password = body.get("password")

    if not email or not nombre or not password:
        return response(400, {"error": "email, nombre y password son requeridos"})
    if rol not in ROLES:
        return response(400, {"error": "rol invalido"})

    cognito_username = body.get("username") or f"user-{uuid.uuid4()}"
    try:
        cognito.admin_create_user(
            UserPoolId=USER_POOL_ID,
            Username=cognito_username,
            UserAttributes=[
                {"Name": "email", "Value": email},
                {"Name": "email_verified", "Value": "true"},
                {"Name": "name", "Value": nombre},
            ],
            MessageAction="SUPPRESS",
        )
        cognito.admin_set_user_password(
            UserPoolId=USER_POOL_ID,
            Username=cognito_username,
            Password=password,
            Permanent=True,
        )
        cognito.admin_add_user_to_group(
            UserPoolId=USER_POOL_ID,
            Username=cognito_username,
            GroupName=rol,
        )
        cognito_user = cognito.admin_get_user(UserPoolId=USER_POOL_ID, Username=cognito_username)
    except ClientError as exc:
        return response(400, {"error": exc.response["Error"]["Message"]})

    usuario_id = next(
        attr["Value"] for attr in cognito_user["UserAttributes"] if attr["Name"] == "sub"
    )
    item = {
        "usuario_id": usuario_id,
        "email": email,
        "cognito_username": cognito_username,
        "nombre": nombre,
        "rol": rol,
        "activo": True,
        "fecha_creacion": today(),
    }
    users_table.put_item(Item=item)
    audit(audit_table, get_user_id(event), "CREAR_USUARIO", detalle=email)
    return response(201, item)


def list_users(event):
    allowed, error = require_role(event, ["Administrador"])
    if not allowed:
        return error

    result = users_table.scan()
    return response(200, {"usuarios": result.get("Items", [])})


def get_user(event, usuario_id):
    current_user_id = get_user_id(event)
    if current_user_id != usuario_id:
        allowed, error = require_role(event, ["Administrador"])
        if not allowed:
            return error

    result = users_table.get_item(Key={"usuario_id": usuario_id})
    item = result.get("Item")
    if not item:
        return response(404, {"error": "Usuario no encontrado"})
    return response(200, item)


def update_user(event, usuario_id):
    allowed, error = require_role(event, ["Administrador"])
    if not allowed:
        return error

    body = parse_body(event)
    if body is None:
        return response(400, {"error": "JSON invalido"})

    current = users_table.get_item(Key={"usuario_id": usuario_id}).get("Item")
    if not current:
        return response(404, {"error": "Usuario no encontrado"})

    updates = {}
    for field in ["nombre", "rol", "activo"]:
        if field in body:
            updates[field] = body[field]

    if "rol" in updates and updates["rol"] not in ROLES:
        return response(400, {"error": "rol invalido"})
    if not updates:
        return response(400, {"error": "No hay campos para actualizar"})

    expression_parts = []
    names = {}
    values = {}
    for index, (field, value) in enumerate(updates.items()):
        name_key = f"#f{index}"
        value_key = f":v{index}"
        names[name_key] = field
        values[value_key] = value
        expression_parts.append(f"{name_key} = {value_key}")

    result = users_table.update_item(
        Key={"usuario_id": usuario_id},
        UpdateExpression="SET " + ", ".join(expression_parts),
        ExpressionAttributeNames=names,
        ExpressionAttributeValues=values,
        ReturnValues="ALL_NEW",
        ConditionExpression="attribute_exists(usuario_id)",
    )

    if "rol" in updates:
        _replace_cognito_group(current.get("cognito_username", current["email"]), updates["rol"])
    if updates.get("activo") is False:
        cognito.admin_disable_user(
            UserPoolId=USER_POOL_ID,
            Username=current.get("cognito_username", current["email"]),
        )

    audit(audit_table, get_user_id(event), "ACTUALIZAR_USUARIO", detalle=usuario_id)
    return response(200, result["Attributes"])


def deactivate_user(event, usuario_id):
    allowed, error = require_role(event, ["Administrador"])
    if not allowed:
        return error

    current = users_table.get_item(Key={"usuario_id": usuario_id}).get("Item")
    if not current:
        return response(404, {"error": "Usuario no encontrado"})

    users_table.update_item(
        Key={"usuario_id": usuario_id},
        UpdateExpression="SET activo = :activo",
        ExpressionAttributeValues={":activo": False},
        ConditionExpression="attribute_exists(usuario_id)",
    )
    cognito.admin_disable_user(
        UserPoolId=USER_POOL_ID,
        Username=current.get("cognito_username", current["email"]),
    )
    audit(audit_table, get_user_id(event), "DESACTIVAR_USUARIO", detalle=usuario_id)
    return response(200, {"message": "Usuario desactivado"})


def _replace_cognito_group(email, new_role):
    for role in ROLES:
        try:
            cognito.admin_remove_user_from_group(
                UserPoolId=USER_POOL_ID,
                Username=email,
                GroupName=role,
            )
        except ClientError:
            pass
    cognito.admin_add_user_to_group(
        UserPoolId=USER_POOL_ID,
        Username=email,
        GroupName=new_role,
    )
