import json
import boto3
import os
from boto3.dynamodb.conditions import Key
dynamodb = boto3.resource('dynamodb')
TABLE_NAME = os.environ.get('USER_TABLE')
table = dynamodb.Table(TABLE_NAME)

def lambda_handler(event, context):
    http_method = event.get('requestContext', {}).get('http', {}).get('method')    
    
    if http_method == 'POST':
        body = json.loads(event.get('body', '{}'))
        usuario_id = body.get('usuario_id')
        
        if not usuario_id:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'usuario_id es requerido'})
            }
            
        table.put_item(Item=body)
        return {
            'statusCode': 201,
            'body': json.dumps({'message': 'Usuario creado exitosamente'})
        }
        
    elif http_method == 'GET':
        query_params = event.get('queryStringParameters') or {}
        usuario_id = query_params.get('usuario_id')
        
        if not usuario_id:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'usuario_id es requerido para consulta'})
            }
            
        response = table.get_item(Key={'usuario_id': usuario_id})
        if 'Item' not in response:
            return {
                'statusCode': 404,
                'body': json.dumps({'error': 'Usuario no encontrado'})
            }
            
        return {
            'statusCode': 200,
            'body': json.dumps(response['Item'])
        }

    return {
        'statusCode': 405,
        'body': json.dumps({'error': f'Metodo {http_method} no soportado'})
    }