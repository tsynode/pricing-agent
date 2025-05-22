"""
Pricing tools for the Strands Agents SDK
"""
from strands import tool
import boto3
import os
import json
from datetime import datetime

# Initialize clients
dynamodb = boto3.resource('dynamodb')
pricing_table = dynamodb.Table(os.environ.get('PRICING_TABLE_NAME', 'pricing-rules'))

@tool
def get_pricing_policy(product_category: str = None) -> str:
    """Get the pricing policy for a specific product category or general policies
    
    Args:
        product_category: Optional product category to get specific policies for
        
    Returns:
        The pricing policy information
    """
    # This function will use the retrieve tool under the hood
    query = f"pricing policies for {product_category}" if product_category else "general pricing policies"
    
    # Use the retrieve tool to get information from the knowledge base
    results = retrieve(query)
    
    if not results or not results.get('results'):
        return "No specific pricing policies found. Please check with the pricing department."
    
    # Format the results
    policy_info = ""
    for result in results.get('results', []):
        policy_info += f"{result.get('text', '')}\n\n"
    
    return policy_info

@tool
def check_price_compliance(product_id: str, price: float) -> dict:
    """Check if a product's price complies with pricing policies
    
    Args:
        product_id: The unique identifier for the product
        price: The current or proposed price of the product
        
    Returns:
        A dictionary with compliance status and explanation
    """
    try:
        # Get pricing rules for the product
        response = pricing_table.get_item(Key={'product_id': product_id})
        
        if 'Item' not in response:
            return {
                "compliant": False,
                "reason": f"No pricing rules found for product {product_id}"
            }
        
        item = response['Item']
        min_price = item.get('min_price', 0)
        max_price = item.get('max_price', float('inf'))
        category = item.get('category', 'Unknown')
        
        # Get the pricing policy for this category
        policy_info = get_pricing_policy(category)
        
        # Check compliance
        compliant = min_price <= price <= max_price
        
        return {
            "compliant": compliant,
            "reason": "Price is within acceptable range" if compliant else f"Price must be between ${min_price} and ${max_price}",
            "min_price": min_price,
            "max_price": max_price,
            "current_price": price,
            "category": category,
            "policy_info": policy_info
        }
    except Exception as e:
        return {
            "compliant": False,
            "reason": f"Error checking compliance: {str(e)}"
        }

@tool
def update_price(product_id: str, new_price: float) -> dict:
    """Update the price of a product
    
    Args:
        product_id: The unique identifier for the product
        new_price: The new price to set for the product
        
    Returns:
        A dictionary with update status and details
    """
    try:
        # First check if the new price is compliant
        compliance_check = check_price_compliance(product_id, new_price)
        
        if not compliance_check.get("compliant", False):
            return {
                "success": False,
                "reason": compliance_check.get("reason", "Price is not compliant with policies"),
                "details": compliance_check
            }
        
        # Get the inventory table
        inventory_table = dynamodb.Table(os.environ.get('INVENTORY_TABLE_NAME', 'inventory'))
        
        # Update the price in the inventory
        response = inventory_table.update_item(
            Key={'product_id': product_id},
            UpdateExpression="set price = :p, last_updated = :t",
            ExpressionAttributeValues={
                ':p': new_price,
                ':t': datetime.now().isoformat()
            },
            ReturnValues="UPDATED_NEW"
        )
        
        return {
            "success": True,
            "product_id": product_id,
            "old_price": compliance_check.get("current_price"),
            "new_price": new_price,
            "updated_at": response.get("Attributes", {}).get("last_updated")
        }
    except Exception as e:
        return {
            "success": False,
            "reason": f"Error updating price: {str(e)}"
        }
