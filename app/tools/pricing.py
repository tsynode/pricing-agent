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
4. Clearance: Items on clearance can be marked down up to 70% of original price.""",
            
            "home": """Home Goods Category Pricing Policies:

1. Kitchen Appliances: Must maintain at least 25% margin over wholesale cost.
2. Bedding and Bath: Premium items should be priced at 40-60% above cost.
3. Seasonal Decorations: Can be marked down up to 60% after the relevant season.
4. Furniture: Should maintain a minimum 30% margin over wholesale cost.""",
            
            "fresh_produce": """Fresh Produce Category Pricing Policies:

1. Perishable Items: Must be sold within 24-48 hours of delivery to maintain freshness.
2. Time-Based Pricing: Between 10am-12pm, prices drop by 2% to encourage morning shopping.
3. Time-Based Pricing: After 12pm, prices drop by 5% to ensure all fresh produce is sold by end of day.
4. Minimum Pricing: Time-based discounts cannot reduce prices below the minimum threshold.
5. Quality Standards: Items showing signs of spoilage must be removed from sale immediately.
6. Organic Products: Must maintain certification documentation and be priced 15-30% higher than conventional equivalents."""
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
        
        # Sample product data for testing - expanded with more examples
        products = {
            # Electronics
            "PROD001": {"min_price": 99.99, "max_price": 199.99, "category": "electronics", "name": "Premium Headphones", "wholesale_cost": 79.99},
            "PROD002": {"min_price": 19.99, "max_price": 39.99, "category": "electronics", "name": "Phone Charger", "wholesale_cost": 12.50},
            "PROD003": {"min_price": 29.99, "max_price": 59.99, "category": "clothing", "name": "Designer T-Shirt", "wholesale_cost": 18.75},
            "PROD004": {"min_price": 49.99, "max_price": 99.99, "category": "clothing", "name": "Jeans", "wholesale_cost": 35.00},
            
            # More Electronics
            "PROD005": {"min_price": 899.99, "max_price": 1299.99, "category": "electronics", "name": "4K Smart TV", "wholesale_cost": 700.00},
            "PROD006": {"min_price": 499.99, "max_price": 799.99, "category": "electronics", "name": "Gaming Console", "wholesale_cost": 400.00},
            "PROD007": {"min_price": 299.99, "max_price": 499.99, "category": "electronics", "name": "Tablet", "wholesale_cost": 220.00},
            "PROD008": {"min_price": 79.99, "max_price": 129.99, "category": "electronics", "name": "Wireless Earbuds", "wholesale_cost": 60.00},
            
            # More Clothing
            "PROD009": {"min_price": 89.99, "max_price": 149.99, "category": "clothing", "name": "Winter Jacket", "wholesale_cost": 65.00},
            "PROD010": {"min_price": 59.99, "max_price": 99.99, "category": "clothing", "name": "Dress Shoes", "wholesale_cost": 45.00},
            "PROD011": {"min_price": 39.99, "max_price": 69.99, "category": "clothing", "name": "Formal Shirt", "wholesale_cost": 30.00},
            "PROD012": {"min_price": 24.99, "max_price": 44.99, "category": "clothing", "name": "Casual Shorts", "wholesale_cost": 18.00},
            
            # Home Goods
            "PROD013": {"min_price": 199.99, "max_price": 349.99, "category": "home", "name": "Coffee Machine", "wholesale_cost": 150.00},
            "PROD014": {"min_price": 129.99, "max_price": 229.99, "category": "home", "name": "Blender Set", "wholesale_cost": 95.00},
            "PROD015": {"min_price": 79.99, "max_price": 149.99, "category": "home", "name": "Bedding Set", "wholesale_cost": 60.00},
            "PROD016": {"min_price": 49.99, "max_price": 89.99, "category": "home", "name": "Towel Set", "wholesale_cost": 35.00},
            
            # Fresh Produce (perishable items with time-based pricing)
            "PROD017": {"min_price": 3.99, "max_price": 5.99, "category": "fresh_produce", "name": "Fresh Bread (Loaf)", "wholesale_cost": 2.50, "perishable": True},
            "PROD018": {"min_price": 2.99, "max_price": 4.99, "category": "fresh_produce", "name": "Milk (1 Gallon)", "wholesale_cost": 2.00, "perishable": True},
            "PROD019": {"min_price": 4.99, "max_price": 7.99, "category": "fresh_produce", "name": "Fresh Strawberries", "wholesale_cost": 3.50, "perishable": True},
            "PROD020": {"min_price": 1.99, "max_price": 3.49, "category": "fresh_produce", "name": "Bananas (Bunch)", "wholesale_cost": 1.20, "perishable": True},
            "PROD021": {"min_price": 5.99, "max_price": 8.99, "category": "fresh_produce", "name": "Fresh Fish Fillet", "wholesale_cost": 4.50, "perishable": True},
            "PROD022": {"min_price": 3.49, "max_price": 5.99, "category": "fresh_produce", "name": "Yogurt (32oz)", "wholesale_cost": 2.25, "perishable": True},
            "PROD023": {"min_price": 2.49, "max_price": 4.29, "category": "fresh_produce", "name": "Fresh Eggs (Dozen)", "wholesale_cost": 1.80, "perishable": True},
            "PROD024": {"min_price": 6.99, "max_price": 9.99, "category": "fresh_produce", "name": "Fresh Cheese", "wholesale_cost": 5.00, "perishable": True}
        }
        
        # Use default values if product not found
        product_data = products.get(product_id, {"min_price": 10.0, "max_price": 100.0, "category": None, "name": "Unknown Product"})
        
        min_price = product_data["min_price"]
        max_price = product_data["max_price"]
        category = product_data["category"]
        
        # Get the pricing policy for this category
        policy_info = get_pricing_policy(category)
        
        # Apply time-based pricing logic only for fresh produce
        from datetime import datetime
        current_hour = datetime.now().hour
        
        # Original price before any time-based discounts
        original_price = price
        discount_percentage = 0
        discount_reason = ""
        
        # Check if this is a fresh produce item (perishable)
        is_fresh_produce = category == "fresh_produce" if category else False
        
        # Apply time-based discounts only to fresh produce
        if is_fresh_produce:
            if 10 <= current_hour < 12:  # Between 10am and 12pm
                discount_percentage = 2
                discount_reason = "2% morning discount for fresh produce (10am-12pm)"
            elif current_hour >= 12:  # After 12pm
                discount_percentage = 5
                discount_reason = "5% afternoon discount for fresh produce (after 12pm)"
            
            # Calculate discounted price if applicable
            if discount_percentage > 0:
                discounted_price = round(price * (1 - discount_percentage / 100), 2)
                # Ensure the discounted price is still above the minimum price
                if discounted_price >= min_price:
                    price = discounted_price
                else:
                    discount_reason += f" (limited to minimum price of ${min_price})"
                    price = min_price
        
        # Check compliance with the final price
        compliant = min_price <= price <= max_price
        
        return {
            "compliant": compliant,
            "reason": "Price is within acceptable range" if compliant else f"Price must be between ${min_price} and ${max_price}",
            "min_price": min_price,
            "max_price": max_price,
            "original_price": original_price,
            "current_price": price,
            "discount_applied": discount_percentage > 0,
            "discount_percentage": discount_percentage if discount_percentage > 0 else None,
            "discount_reason": discount_reason if discount_percentage > 0 else None,
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
    print(f"update_price called with product_id: {product_id}, new_price: {new_price}")
    
    try:
        # First check if the new price is compliant
        compliance_check = check_price_compliance(product_id, new_price)
        
        if not compliance_check.get("compliant", False):
            return {
                "success": False,
                "reason": compliance_check.get("reason", "Price is not compliant with policies"),
                "details": compliance_check
            }
        
        try:
            # Try to update in DynamoDB first
            print(f"Attempting to update price in DynamoDB table: {os.environ.get('INVENTORY_TABLE_NAME', 'inventory')}")
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
            
            print(f"DynamoDB update response: {response}")
            
            return {
                "success": True,
                "product_id": product_id,
                "old_price": compliance_check.get("original_price"),
                "new_price": new_price,
                "discount_applied": compliance_check.get("discount_applied", False),
                "discount_percentage": compliance_check.get("discount_percentage"),
                "discount_reason": compliance_check.get("discount_reason"),
                "updated_at": response.get("Attributes", {}).get("last_updated")
            }
        except Exception as e:
            print(f"Error updating price in DynamoDB: {str(e)}")
            
        # Fallback for demo purposes - simulate a successful update
        print("Falling back to simulated price update for demo purposes")
        current_time = datetime.now().isoformat()
        
        return {
            "success": True,
            "product_id": product_id,
            "product_name": "Unknown Product",  # Will be filled if product is found
            "category": compliance_check.get("category", "Unknown"),
            "old_price": compliance_check.get("original_price"),
            "new_price": new_price,
            "discount_applied": compliance_check.get("discount_applied", False),
            "discount_percentage": compliance_check.get("discount_percentage"),
            "discount_reason": compliance_check.get("discount_reason"),
            "updated_at": current_time,
            "note": "This is a simulated update for demonstration purposes. No actual database was modified."
        }
    except Exception as e:
        print(f"Unexpected error in update_price: {str(e)}")
        return {
            "success": False,
            "reason": f"Error updating price: {str(e)}",
            "product_id": product_id,
            "attempted_price": new_price,
            "error_details": str(e)
        }
