import os

import boto3
from botocore.exceptions import ClientError

from common import audit


dynamodb = boto3.resource("dynamodb")
ses = boto3.client("ses")

ORDER_TABLE = os.environ["ORDER_TABLE"]
PRODUCT_TABLE = os.environ["PRODUCT_TABLE"]
AUDIT_TABLE = os.environ["AUDIT_TABLE"]
ADMIN_EMAIL = os.environ["ADMIN_EMAIL"]
NOTIFICATION_EMAIL = os.environ["NOTIFICATION_EMAIL"]

orders_table = dynamodb.Table(ORDER_TABLE)
products_table = dynamodb.Table(PRODUCT_TABLE)
audit_table = dynamodb.Table(AUDIT_TABLE)


def lambda_handler(event, context):
    detail = event.get("detail", {})
    pedido_id = detail.get("pedido_id")
    usuario_id = detail.get("usuario_id")
    items = detail.get("items", [])

    inventory_ok = update_inventory(pedido_id, usuario_id, items)
    send_order_email(detail, inventory_ok)
    audit(
        audit_table,
        usuario_id,
        "PROCESAR_EVENTO_PEDIDO",
        "EXITOSO" if inventory_ok else "FALLIDO",
        pedido_id,
    )
    return {"statusCode": 200, "inventory_ok": inventory_ok}


def update_inventory(pedido_id, usuario_id, items):
    inventory_ok = True
    for item in items:
        producto_id = item["producto_id"]
        cantidad = int(item["cantidad"])
        try:
            products_table.update_item(
                Key={"producto_id": producto_id},
                UpdateExpression=(
                    "SET inventario = inventario - :cantidad, "
                    "vendidos = if_not_exists(vendidos, :zero) + :cantidad"
                ),
                ExpressionAttributeValues={
                    ":cantidad": cantidad,
                    ":zero": 0,
                },
                ConditionExpression="inventario >= :cantidad AND attribute_exists(producto_id)",
            )
            audit(audit_table, usuario_id, "ACTUALIZAR_INVENTARIO", detalle=producto_id)
        except ClientError:
            inventory_ok = False
            audit(audit_table, usuario_id, "ACTUALIZAR_INVENTARIO", "FALLIDO", producto_id)

    if not inventory_ok and pedido_id:
        orders_table.update_item(
            Key={"pedido_id": pedido_id},
            UpdateExpression="SET requiere_revision = :revision",
            ExpressionAttributeValues={":revision": True},
        )
    return inventory_ok


def send_order_email(detail, inventory_ok):
    pedido_id = detail.get("pedido_id", "sin-id")
    total = detail.get("total", 0)
    estado = "procesado" if inventory_ok else "requiere revision"
    recipients = [NOTIFICATION_EMAIL]
    customer_email = detail.get("usuario_email")
    if customer_email and customer_email not in recipients:
        recipients.append(customer_email)

    for recipient in recipients:
        try:
            result = ses.send_email(
                Source=f"CloudShop Enterprise <{ADMIN_EMAIL}>",
                Destination={"ToAddresses": [recipient]},
                Message={
                    "Subject": {"Data": f"CloudShop - Pedido creado {pedido_id}"},
                    "Body": {
                        "Text": {
                            "Data": (
                                "CloudShop Enterprise\n\n"
                                f"Pedido: {pedido_id}\n"
                                f"Cliente: {customer_email or 'sin correo'}\n"
                                f"Total: {total}\n"
                                f"Estado del inventario: {estado}\n\n"
                                "Este correo fue enviado automaticamente por AWS SES."
                            )
                        }
                    },
                },
            )
            print(f"SES MessageId: {result.get('MessageId')} recipient={recipient}")
        except ClientError as exc:
            print(f"SES send failed recipient={recipient}: {exc.response['Error']['Message']}")
