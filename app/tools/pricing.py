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
pricing_table = dynamodb.Table(os.environ.get('PRICING_TABLE_NAME', 'pricing-rules'))

@tool
def get_pricing_policy(product_category: str = None) -> str:
    """Get the pricing policy for a specific product category or general policies
    
    Args:
        product_category: Optional product category to get specific policies for
        
    Returns:
        The pricing policy information
    """
    try:
        # This function will use the retrieve tool under the hood
        query = f"pricing policies for {product_category}" if product_category else "general pricing policies"
        
        # Use the retrieve tool to get information from the knowledge base
        results = retrieve(query)
        
        if not results or not results.get('results'):
            print(f"No results from knowledge base for {query}, using hardcoded policies")
            raise Exception("Using hardcoded policies")
        
        # Format the results
        policy_info = ""
        for result in results.get('results', []):
            policy_info += f"{result.get('text', '')}\n\n"
        
        return policy_info
    except Exception as e:
        print(f"Error retrieving policy from knowledge base: {str(e)}. Using hardcoded policies.")
        # Fallback to hardcoded policies
        policies = {
            "general": """General Pricing Policies:

1. Minimum Margin: All products must maintain at least a 20% margin over wholesale cost.
2. Competitive Pricing: Prices should be within 10% of major competitors.
3. Discount Approval: Discounts exceeding 15% require manager approval.
4. Price Changes: Price increases should not exceed 5% in a 30-day period.
5. Bundle Pricing: Bundle discounts should not exceed 20% of the combined regular prices.""",
            
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
        else:
            return policies["general"]

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
        try:
            response = pricing_table.get_item(Key={'product_id': product_id})
            
            if 'Item' not in response:
                # Fallback to hardcoded data for demo purposes
                print(f"No pricing rules found in DynamoDB for product {product_id}, using hardcoded data")
                raise Exception("Using hardcoded data")
            
            item = response['Item']
            min_price = item.get('min_price', 0)
            max_price = item.get('max_price', float('inf'))
            category = item.get('category', 'Unknown')
            name = item.get('name', f"Product {product_id}")
            wholesale_cost = item.get('wholesale_cost', 0)
        except Exception as e:
            print(f"Error accessing DynamoDB: {str(e)}. Using hardcoded data instead.")
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
            product_data = products.get(product_id, {
                "min_price": 0, 
                "max_price": float('inf'),
                "category": "Unknown",
                "name": f"Product {product_id}",
                "wholesale_cost": 0
            })
            
            min_price = product_data.get("min_price")
            max_price = product_data.get("max_price")
            category = product_data.get("category")
            name = product_data.get("name")
            wholesale_cost = product_data.get("wholesale_cost")
        
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
        
        result = {
            "compliant": compliant,
            "reason": "Price is within acceptable range" if compliant else f"Price must be between ${min_price} and ${max_price}",
            "min_price": min_price,
            "max_price": max_price,
            "current_price": original_price,  # Original price before any discounts
            "final_price": price,  # Price after any discounts
            "category": category,
            "product_name": name,
            "policy_info": policy_info
        }
        
        # Add discount information if applicable
        if discount_percentage > 0:
            result["discount_applied"] = True
            result["discount_percentage"] = discount_percentage
            result["discount_reason"] = discount_reason
        
        return result
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
        
        try:
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
                "new_price": compliance_check.get("final_price"),  # Use the final price after any discounts
                "updated_at": response.get("Attributes", {}).get("last_updated"),
                "discount_applied": compliance_check.get("discount_applied", False),
                "discount_percentage": compliance_check.get("discount_percentage"),
                "discount_reason": compliance_check.get("discount_reason")
            }
        except Exception as e:
            print(f"Error updating price in DynamoDB: {str(e)}. Simulating update for demo.")
            # Simulate a successful update for demo purposes
            current_time = datetime.now().isoformat()
            
            return {
                "success": True,
                "product_id": product_id,
                "old_price": compliance_check.get("current_price"),
                "new_price": compliance_check.get("final_price"),  # Use the final price after any discounts
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
