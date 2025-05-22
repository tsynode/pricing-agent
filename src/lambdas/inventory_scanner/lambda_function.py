import json
import os
import uuid
import logging
import boto3
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
sqs = boto3.client('sqs')

# Environment variables
SQS_QUEUE_URL = os.environ.get('SQS_QUEUE_URL')
BATCH_SIZE = int(os.environ.get('BATCH_SIZE', 100))

def lambda_handler(event, context):
    """
    Handles inventory scanning and batch distribution
    
    Input Event Types:
    1. EventBridge scheduled: {"source": "scheduled", "timestamp": "..."}
    2. Bedrock Agent call: {"action": "scan_inventory", "parameters": {...}}
    
    Functionality:
    - Scan DynamoDB inventory table with pagination
    - Create batches of 100 item IDs
    - Send each batch to SQS as individual messages
    - Return summary of items queued
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    # Determine if this is a scheduled run or agent invocation
    is_scheduled = event.get('source') == 'scheduled'
    
    # Extract category filter if provided by agent
    category_filter = None
    if not is_scheduled and 'parameters' in event:
        category_filter = event.get('parameters', {}).get('category')
    
    # Get inventory table name based on environment
    table_name = get_inventory_table_name()
    table = dynamodb.Table(table_name)
    
    # Scan inventory with pagination
    total_items = 0
    batches_created = 0
    
    try:
        # Start scanning with pagination
        scan_kwargs = {
            'Select': 'SPECIFIC_ATTRIBUTES',
            'AttributesToGet': ['item_id']
        }
        
        # Add filter expression if category is specified
        if category_filter:
            scan_kwargs['FilterExpression'] = 'category = :category'
            scan_kwargs['ExpressionAttributeValues'] = {':category': category_filter}
        
        done = False
        start_key = None
        item_batch = []
        
        while not done:
            if start_key:
                scan_kwargs['ExclusiveStartKey'] = start_key
            
            response = table.scan(**scan_kwargs)
            items = response.get('Items', [])
            
            # Process items in this scan batch
            for item in items:
                item_batch.append(item['item_id'])
                total_items += 1
                
                # When we reach batch size, send to SQS
                if len(item_batch) >= BATCH_SIZE:
                    send_batch_to_sqs(item_batch)
                    batches_created += 1
                    item_batch = []
            
            # Check if we need to continue scanning
            start_key = response.get('LastEvaluatedKey')
            done = start_key is None
        
        # Send any remaining items
        if item_batch:
            send_batch_to_sqs(item_batch)
            batches_created += 1
        
        logger.info(f"Completed scanning. Total items: {total_items}, Batches created: {batches_created}")
        
        return {
            'batches_created': batches_created,
            'total_items': total_items
        }
        
    except Exception as e:
        logger.error(f"Error scanning inventory: {str(e)}")
        raise

def send_batch_to_sqs(item_ids):
    """
    Send a batch of item IDs to SQS for processing
    """
    batch_id = str(uuid.uuid4())
    message_body = {
        'batch_id': batch_id,
        'item_ids': item_ids,
        'batch_size': len(item_ids),
        'timestamp': datetime.utcnow().isoformat()
    }
    
    try:
        response = sqs.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(message_body)
        )
        logger.info(f"Sent batch {batch_id} with {len(item_ids)} items to SQS")
        return response
    except Exception as e:
        logger.error(f"Error sending batch to SQS: {str(e)}")
        raise

def get_inventory_table_name():
    """
    Get the inventory table name based on environment
    """
    # This could be enhanced to dynamically determine the table name
    # based on environment variables or other configuration
    return f"{os.environ.get('AWS_LAMBDA_FUNCTION_NAME', 'pricing-agent').split('-')[0]}-inventory"
