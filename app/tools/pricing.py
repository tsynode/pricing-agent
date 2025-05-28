"""
Pricing tools for the Strands Agents SDK
"""
from strands import tool
from strands_tools import retrieve
import boto3
import os
import json
from datetime import datetime

# Initialize clients
dynamodb = boto3.resource('dynamodb')
pricing_table_name = os.environ.get('PRICING_TABLE_NAME', 'pricing-rules')
pricing_table = dynamodb.Table(pricing_table_name)
print(f"Initialized pricing table: {pricing_table_name}")

@tool
def get_pricing_policy(product_category: str = None) -> str:
    """Get the pricing policy for a specific product category or general policies
    
    Args:
        product_category: Optional product category to get specific policies for
        
    Returns:
        The pricing policy information
    """
    print(f"get_pricing_policy called with category: {product_category}")
    
    try:
        # Try to use the retrieve tool first
        query = f"pricing policies for {product_category}" if product_category else "general pricing policies"
        print(f"Attempting to retrieve with query: {query}")
        
        try:
            results = retrieve(query)
            print(f"Retrieve results: {results}")
            
            if results and results.get('results'):
                policy_info = ""
                for result in results.get('results', []):
                    policy_info += f"{result.get('text', '')}\n\n"
                return policy_info
        except Exception as e:
            print(f"Error using retrieve tool: {str(e)}")
        
        # Fallback to hardcoded policies if retrieve fails
        print("Falling back to hardcoded policies")
        
        # Hardcoded policies for testing
        policies = {
            None: """The company has a set of general pricing policies that apply across all product categories:

1. Minimum Pricing: All products must be priced at least 20% above the wholesale cost to ensure adequate margins.
2. Maximum Markup: The maximum markup allowed on any product is 100% of the wholesale cost.
3. Rounding: All prices must be rounded to the nearest whole dollar amount.
4. Promotional Pricing: Temporary promotional pricing discounts of up to 30% off the regular price are allowed, but must be time-limited.""",
            
            "electronics": """Electronics Category Pricing Policies:

1. Premium Products: High-end electronics should maintain a minimum 30% margin.
2. Accessories: Small accessories should be priced at least 40% above cost.
3. Extended Warranties: Must be priced between 10-20% of the product's retail price.
4. Bundle Discounts: Bundle discounts should not exceed 15% of the combined regular prices.""",
            
            "clothing": """Clothing Category Pricing Policies:

1. Seasonal Items: End-of-season markdowns should not exceed 50% of original price.
2. Designer Brands: Must maintain manufacturer's suggested retail price (MSRP).
3. Basic Items: Should be priced competitively with market averages.
4. Clearance: Items on clearance can be marked down up to 70% of original price."""
        }
        
        if product_category and product_category.lower() in policies:
            return policies[product_category.lower()]
        return policies[None]
        
    except Exception as e:
        print(f"Unexpected error in get_pricing_policy: {str(e)}")
        return "Unable to retrieve pricing policies at this time. Please try again later."

@tool
def check_price_compliance(product_id: str, price: float) -> dict:
    """Check if a product's price complies with pricing policies
    
    Args:
        product_id: The unique identifier for the product
        price: The current or proposed price of the product
        
    Returns:
        A dictionary with compliance status and explanation
    """
    print(f"check_price_compliance called with product_id: {product_id}, price: {price}")
    
    try:
        # Try to get pricing rules from DynamoDB first
        try:
            print(f"Attempting to get item from DynamoDB table: {pricing_table_name}")
            response = pricing_table.get_item(Key={'product_id': product_id})
            print(f"DynamoDB response: {response}")
            
            if 'Item' in response:
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
            print(f"Error accessing DynamoDB: {str(e)}")
        
        # Fallback to hardcoded data for testing
        print("Falling back to hardcoded product data")
        
        # Sample product data for testing
        products = {
            "PROD001": {"min_price": 99.99, "max_price": 199.99, "category": "electronics", "name": "Premium Headphones"},
            "PROD002": {"min_price": 19.99, "max_price": 39.99, "category": "electronics", "name": "Phone Charger"},
            "PROD003": {"min_price": 29.99, "max_price": 59.99, "category": "clothing", "name": "Designer T-Shirt"},
            "PROD004": {"min_price": 49.99, "max_price": 99.99, "category": "clothing", "name": "Jeans"}
        }
        
        # Use default values if product not found
        product_data = products.get(product_id, {"min_price": 10.0, "max_price": 100.0, "category": None, "name": "Unknown Product"})
        
        min_price = product_data["min_price"]
        max_price = product_data["max_price"]
        category = product_data["category"]
        
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
        print(f"Unexpected error in check_price_compliance: {str(e)}")
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
