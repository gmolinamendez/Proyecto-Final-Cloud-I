import json
import boto3
import os
import uuid
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
AUDIT_TABLE = os.environ.get('AUDIT_TABLE')
PRODUCT_TABLE = os.environ.get('PRODUCT_TABLE')

def lambda_handler(event, context):
    order_data = event.get('detail', {})
    usuario = order_data.get('usuario_id', 'anonimo')
    producto_id = order_data.get('producto_id')
    cantidad = order_data.get('cantidad', 1)
    audit_table = dynamodb.Table(AUDIT_TABLE)
    audit_table.put_item(
        Item={
            'auditoria_id': str(uuid.uuid4()),
            'usuario': usuario,
            'accion': 'CREACION_PEDIDO',
            'fecha': datetime.now().isoformat().split('T')[0],
            'resultado': 'EXITOSO'
        }
    )
    if producto_id:
        product_table = dynamodb.Table(PRODUCT_TABLE)
        try:
            product_table.update_item(
                Key={'producto_id': producto_id},
                UpdateExpression="set inventario = inventario - :val",
                ExpressionAttributeValues={':val': cantidad},
                ConditionExpression="inventario >= :val"
            )
        except Exception as e:
            print(f"No se pudo actualizar inventario: {str(e)}")
            
    print("Evento procesado, auditoria guardada e inventario actualizado.")
    return {'statusCode': 200, 'body': 'Procesado correctamente'}