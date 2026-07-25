import json
import uuid
from datetime import datetime, timezone
from decimal import Decimal


ROLES = {"Administrador", "Operador", "Cliente"}


def to_jsonable(value):
    if isinstance(value, Decimal):
        if value % 1 == 0:
            return int(value)
        return float(value)
    if isinstance(value, list):
        return [to_jsonable(item) for item in value]
    if isinstance(value, dict):
        return {key: to_jsonable(item) for key, item in value.items()}
    return value


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,Authorization",
            "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
        },
        "body": json.dumps(to_jsonable(body), ensure_ascii=False),
    }


def parse_body(event):
    raw_body = event.get("body") or "{}"
    if isinstance(raw_body, dict):
        return raw_body
    try:
        return json.loads(raw_body)
    except json.JSONDecodeError:
        return None


def get_claims(event):
    authorizer = event.get("requestContext", {}).get("authorizer", {})
    if "jwt" in authorizer:
        return authorizer.get("jwt", {}).get("claims", {}) or {}
    return authorizer.get("claims", {}) or {}


def get_user_id(event):
    return get_claims(event).get("sub")


def get_user_email(event):
    return get_claims(event).get("email")


def get_groups(event):
    groups = get_claims(event).get("cognito:groups", "")
    if isinstance(groups, list):
        return groups
    return [
        group.strip()
        for group in str(groups).replace("[", "").replace("]", "").split(",")
        if group.strip()
    ]


def has_role(event, allowed_roles):
    groups = get_groups(event)
    return any(role in groups for role in allowed_roles)


def require_role(event, allowed_roles):
    if has_role(event, allowed_roles):
        return True, None
    return False, response(403, {"error": "Forbidden", "required_roles": allowed_roles})


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def today():
    return datetime.now(timezone.utc).date().isoformat()


def audit(audit_table, usuario, accion, resultado="EXITOSO", detalle=None):
    if audit_table is None:
        return
    item = {
        "auditoria_id": str(uuid.uuid4()),
        "usuario": usuario or "sistema",
        "accion": accion,
        "fecha": today(),
        "timestamp": now_iso(),
        "resultado": resultado,
    }
    if detalle:
        item["detalle"] = detalle
    audit_table.put_item(Item=item)
