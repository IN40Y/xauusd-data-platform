import os
import json
import boto3
from datetime import datetime, timedelta

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    """
    Query API for fetching XAU/USD data based on timeframe and date range.
    """
    print(f"Event: {event}")

    # Parse query parameters
    query_params = event.get('queryStringParameters', {}) or {}
    timeframe = query_params.get('timeframe', '1min')
    hours = int(query_params.get('hours', 24))
    
    # Validate timeframe
    valid_timeframes = ['1min', '5min', '1h']
    if timeframe not in valid_timeframes:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': f'Invalid timeframe. Must be one of: {valid_timeframes}'})
        }

    # Calculate time range
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(hours=hours)
    
    start_time_iso = start_time.isoformat() + 'Z'
    end_time_iso = end_time.isoformat() + 'Z'

    try:
        # Query DynamoDB for data in the specified range
        response = table.query(
            KeyConditionExpression='timeframe = :tf AND #ts BETWEEN :start AND :end',
            ExpressionAttributeNames={'#ts': 'timestamp'},
            ExpressionAttributeValues={
                ':tf': timeframe,
                ':start': start_time_iso,
                ':end': end_time_iso
            }
        )

        items = response.get('Items', [])
        
        # Format response
        formatted_data = []
        for item in items:
            formatted_data.append({
                'timestamp': item['timestamp'],
                'open': item['open'],
                'high': item['high'],
                'low': item['low'],
                'close': item['close'],
                'volume': item.get('volume', '0')
            })

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'  # Enable CORS
            },
            'body': json.dumps({
                'data': formatted_data,
                'timeframe': timeframe,
                'count': len(formatted_data)
            })
        }

    except Exception as e:
        print(f"Error querying data: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }