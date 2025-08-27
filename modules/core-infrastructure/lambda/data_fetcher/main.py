import os
import json
import boto3
import requests
from datetime import datetime, timedelta

# Initialize clients outside the handler for reuse
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])
API_KEY = os.environ['API_KEY']
API_URL = os.environ.get('API_URL', 'https://api.twelvedata.com/time_series')

def lambda_handler(event, context):
    """
    Fetches XAU/USD data from external API and stores it in DynamoDB.
    Pre-aggregates 5m and 1h timeframes from 1m data.
    """
    print(f"Event: {event}")

    # Define parameters for API call (1 minute data)
    symbol = "XAU/USD"
    interval = "1min"
    params = {
        'symbol': symbol,
        'interval': interval,
        'apikey': API_KEY,
        'outputsize': 1  # Get only the latest data point
    }

    try:
        # Fetch data from external API
        response = requests.get(API_URL, params=params)
        response.raise_for_status()  # Raise exception for bad status codes
        data = response.json()

        if 'values' not in data:
            print(f"Unexpected API response: {data}")
            if 'code' in data:
                raise Exception(f"API Error: {data['code']} - {data.get('message', 'No message')}")
            return {'statusCode': 500, 'body': json.dumps('No data received from API')}

        # Get the latest data point
        latest_data = data['values'][0]
        timestamp_str = latest_data['datetime']
        # Convert to ISO format for consistency
        timestamp_dt = datetime.strptime(timestamp_str, '%Y-%m-%d %H:%M:%S')
        timestamp_iso = timestamp_dt.isoformat() + 'Z'

        # Prepare item for DynamoDB
        item = {
            'timestamp': timestamp_iso,
            'timeframe': '1min',
            'symbol': symbol,
            'open': latest_data['open'],
            'high': latest_data['high'],
            'low': latest_data['low'],
            'close': latest_data['close'],
            'volume': latest_data.get('volume', '0'),
            'ttl': int((timestamp_dt + timedelta(days=7)).timestamp())  # Auto-expire after 7 days
        }

        # Write 1m data to DynamoDB
        table.put_item(Item=item)
        print(f"Successfully stored 1m data for {timestamp_iso}")

        # Pre-aggregate higher timeframes
        aggregate_timeframes(timestamp_dt, symbol)

        return {
            'statusCode': 200,
            'body': json.dumps('Data fetched and processed successfully')
        }

    except requests.exceptions.RequestException as e:
        print(f"API request failed: {e}")
        return {'statusCode': 500, 'body': json.dumps('API request failed')}
    except Exception as e:
        print(f"Error: {e}")
        return {'statusCode': 500, 'body': json.dumps('Internal error')}

def aggregate_timeframes(timestamp_dt, symbol):
    """Aggregate 5m and 1h timeframes from recent 1m data"""
    # Only aggregate on 5-minute intervals for 5m data
    if timestamp_dt.minute % 5 == 0:
        aggregate_data('5min', timestamp_dt, symbol)
    
    # Only aggregate on the hour for 1h data
    if timestamp_dt.minute == 0:
        aggregate_data('1h', timestamp_dt, symbol)

def aggregate_data(timeframe, timestamp_dt, symbol):
    """Aggregate data for specified timeframe"""
    # Calculate start time for aggregation window
    if timeframe == '5min':
        start_time = timestamp_dt - timedelta(minutes=4)
    elif timeframe == '1h':
        start_time = timestamp_dt - timedelta(minutes=59)
    else:
        return

    start_time_iso = start_time.isoformat() + 'Z'
    end_time_iso = timestamp_dt.isoformat() + 'Z'

    try:
        # Query 1m data for the aggregation window
        response = table.query(
            KeyConditionExpression='timeframe = :tf AND #ts BETWEEN :start AND :end',
            ExpressionAttributeNames={'#ts': 'timestamp'},
            ExpressionAttributeValues={
                ':tf': '1min',
                ':start': start_time_iso,
                ':end': end_time_iso
            }
        )

        items = response.get('Items', [])
        if not items:
            print(f"No 1m data found to aggregate {timeframe} for {end_time_iso}")
            return

        # Calculate aggregated values
        opens = [float(item['open']) for item in items]
        highs = [float(item['high']) for item in items]
        lows = [float(item['low']) for item in items]
        closes = [float(item['close']) for item in items]
        volumes = [float(item.get('volume', 0)) for item in items]

        aggregated_item = {
            'timestamp': end_time_iso,
            'timeframe': timeframe,
            'symbol': symbol,
            'open': opens[0],
            'high': max(highs),
            'low': min(lows),
            'close': closes[-1],
            'volume': str(sum(volumes)),
            'ttl': int((timestamp_dt + timedelta(days=7)).timestamp())
        }

        # Write aggregated data to DynamoDB
        table.put_item(Item=aggregated_item)
        print(f"Successfully aggregated {timeframe} data for {end_time_iso}")

    except Exception as e:
        print(f"Error aggregating {timeframe} data: {e}")