import json
import os
import logging
import boto3
from datetime import datetime
from decimal import Decimal

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')

# Environment variables
PRODUCT_FINANCIALS_TABLE = os.environ.get('PRODUCT_FINANCIALS_TABLE')
INVENTORY_TABLE = os.environ.get('INVENTORY_TABLE')

# Helper class to convert Decimal to float for JSON serialization
class DecimalEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, Decimal):
            return float(o)
        return super(DecimalEncoder, self).default(o)

def lambda_handler(event, context):
    """
    Provides pricing tools for the Bedrock agent
    
    Input: Action and parameters from Bedrock agent
    
    Actions:
    1. get_item_price: Retrieve current price and metadata for an item
    2. update_price: Update item price with audit trail
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    # Extract action and parameters
    action = event.get('action')
    parameters = event.get('parameters', {})
    
    if action == 'get_item_price':
        return get_item_price(parameters.get('item_id'))
    elif action == 'update_price':
        return update_price(
            parameters.get('item_id'),
            parameters.get('new_price'),
            parameters.get('reason')
        )
    else:
        error_message = f"Unknown action: {action}"
        logger.error(error_message)
        return {
            'error': error_message
        }

def get_item_price(item_id):
    """
    Retrieve current price and metadata for an item
    
    Returns:
    {
        "item_id": "12345",
        "current_price": 29.99,
        "category": "electronics",
        "last_updated": "2025-01-15T10:30:00Z",
        "cost": 15.50,
        "margin_percent": 48.2
    }
    """
    if not item_id:
        return {'error': 'item_id is required'}
    
    try:
        # Get item from DynamoDB
        table = dynamodb.Table(PRODUCT_FINANCIALS_TABLE)
        response = table.get_item(
            Key={'item_id': item_id}
        )
        
        item = response.get('Item')
        
        if not item:
            return {
                'error': f"Item not found: {item_id}"
            }
        
        # Calculate margin percentage if cost and price are available
        if 'cost' in item and 'current_price' in item:
            cost = float(item['cost'])
            price = float(item['current_price'])
            if cost > 0:
                margin = ((price - cost) / price) * 100
                item['margin_percent'] = round(margin, 2)
        
        # Convert Decimal to float for JSON serialization
        return json.loads(json.dumps(item, cls=DecimalEncoder))
        
    except Exception as e:
        error_message = f"Error retrieving item price: {str(e)}"
        logger.error(error_message)
        return {'error': error_message}

def update_price(item_id, new_price, reason):
    """
    Update item price with audit trail
    
    Parameters:
    - item_id: Product identifier
    - new_price: New price to set
    - reason: AI agent's reasoning for change
    
    Returns:
    {
        "success": true,
        "old_price": 29.99,
        "new_price": 32.99,
        "updated_at": "2025-01-15T11:00:00Z"
    }
    """
    if not item_id:
        return {'error': 'item_id is required'}
    
    if new_price is None:
        return {'error': 'new_price is required'}
    
    if not reason:
        return {'error': 'reason is required'}
    
    try:
        # Convert new_price to Decimal for DynamoDB
        new_price_decimal = Decimal(str(new_price))
        
        # Get current item to retrieve old price
        table = dynamodb.Table(PRODUCT_FINANCIALS_TABLE)
        response = table.get_item(
            Key={'item_id': item_id}
        )
        
        item = response.get('Item')
        
        if not item:
            return {
                'error': f"Item not found: {item_id}"
            }
        
        old_price = float(item.get('current_price', 0))
        
        # Update the item with new price
        timestamp = datetime.utcnow().isoformat()
        
        update_response = table.update_item(
            Key={'item_id': item_id},
            UpdateExpression="SET current_price = :price, last_updated = :timestamp, price_change_reason = :reason",
            ExpressionAttributeValues={
                ':price': new_price_decimal,
                ':timestamp': timestamp,
                ':reason': reason
            },
            ReturnValues="UPDATED_NEW"
        )
        
        # Log the price change for audit purposes
        logger.info(f"Price updated for item {item_id}: {old_price} -> {new_price}, reason: {reason}")
        
        return {
            'success': True,
            'old_price': old_price,
            'new_price': float(new_price),
            'updated_at': timestamp
        }
        
    except Exception as e:
        error_message = f"Error updating price: {str(e)}"
        logger.error(error_message)
        return {'error': error_message}
