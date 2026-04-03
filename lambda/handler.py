import json
import boto3
import os

def handler(event, context):
    # Utiliser le hostname Docker de LocalStack au lieu de localhost
    endpoint = os.environ.get('ENDPOINT_URL', 'http://host.docker.internal:4566')
    
    # Fallback : IP du bridge Docker LocalStack
    try:
        ec2 = boto3.client('ec2', endpoint_url=endpoint, region_name='us-east-1')
        ec2.describe_instances(MaxResults=5)
    except Exception:
        endpoint = 'http://172.17.0.2:4566'
        ec2 = boto3.client('ec2', endpoint_url=endpoint, region_name='us-east-1')

    params = event.get('queryStringParameters') or {}
    action = params.get('action', '')
    instance_id = params.get('instance_id', '')

    if not action or not instance_id:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Missing action or instance_id parameter'})
        }

    try:
        if action == 'start':
            ec2.start_instances(InstanceIds=[instance_id])
            message = f'Instance {instance_id} started'
        elif action == 'stop':
            ec2.stop_instances(InstanceIds=[instance_id])
            message = f'Instance {instance_id} stopped'
        elif action == 'status':
            response = ec2.describe_instances(InstanceIds=[instance_id])
            state = response['Reservations'][0]['Instances'][0]['State']['Name']
            message = f'Instance {instance_id} is {state}'
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Unknown action: {action}'})
            }

        return {
            'statusCode': 200,
            'body': json.dumps({'message': message})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }