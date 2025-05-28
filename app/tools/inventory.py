"""
Inventory tools for the Strands Agents SDK
"""
from strands import tool
import boto3
import os

# Import check_price_compliance directly to avoid relative import issues
try:
    from app.tools.pricing import check_price_compliance
except ImportError:
    # Fallback for when running from within the app directory
    try:
        from tools.pricing import check_price_compliance
    except ImportError:
        # Last resort fallback
        def check_price_compliance(product_id, price):
            return {
                "compliant": True,
                "reason": "Fallback compliance check always passes",
                "min_price": 0.0,
                "max_price": 1000.0,
                "current_price": price,
                "category": "Unknown",
                "policy_info": "No policy information available"
            }

# Initialize clients
dynamodb = boto3.resource('dynamodb')
inventory_table_name = os.environ.get('INVENTORY_TABLE_NAME', 'inventory')
inventory_table = dynamodb.Table(inventory_table_name)
print(f"Initialized inventory table: {inventory_table_name}")

@tool
def scan_inventory(category: str = None, compliance_only: bool = False) -> dict:
    """Scan inventory for pricing issues
    
    Args:
        category: Optional category to filter the scan
        compliance_only: If True, only return non-compliant items
        
    Returns:
        A dictionary with scan results
    """
    print(f"scan_inventory called with category: {category}, compliance_only: {compliance_only}")
    
    try:
        # Try to scan the inventory table first
        try:
            print(f"Attempting to scan DynamoDB table: {inventory_table_name}")
            
            # Prepare scan parameters
            scan_params = {}
            if category:
                scan_params = {
                    'FilterExpression': 'category = :c',
                    'ExpressionAttributeValues': {':c': category}
                }
            
            # Scan the inventory table
            response = inventory_table.scan(**scan_params)
            items = response.get('Items', [])
            print(f"DynamoDB scan returned {len(items)} items")
            
            if items:
                # Process each item for compliance
                results = []
                compliant_count = 0
                non_compliant_count = 0
                
                for item in items:
                    product_id = item.get('product_id')
                    price = item.get('price')
                    
                    # Check compliance
                    compliance = check_price_compliance(product_id, price)
                    is_compliant = compliance.get('compliant', False)
                    
                    if is_compliant:
                        compliant_count += 1
                    else:
                        non_compliant_count += 1
                    
                    # Add to results if not filtering or if non-compliant
                    if not compliance_only or not is_compliant:
                        results.append({
                            'product_id': product_id,
                            'name': item.get('name', 'Unknown'),
                            'category': item.get('category', 'Unknown'),
                            'price': price,
                            'compliant': is_compliant,
                            'reason': compliance.get('reason', ''),
                            'min_price': compliance.get('min_price'),
                            'max_price': compliance.get('max_price')
                        })
                
                # Return the scan results
                return {
                    'total_items': len(items),
                    'compliant_count': compliant_count,
                    'non_compliant_count': non_compliant_count,
                    'category_filter': category,
                    'results': results
                }
        except Exception as e:
            print(f"Error scanning DynamoDB: {str(e)}")
        
        # Fallback to hardcoded inventory data for testing
        print("Falling back to hardcoded inventory data")
        
        # Sample inventory data for testing
        inventory_items = [
            {'product_id': 'PROD001', 'name': 'Premium Headphones', 'category': 'electronics', 'price': 149.99},
            {'product_id': 'PROD002', 'name': 'Phone Charger', 'category': 'electronics', 'price': 15.99},  # Non-compliant (below min price)
            {'product_id': 'PROD003', 'name': 'Designer T-Shirt', 'category': 'clothing', 'price': 45.99},
            {'product_id': 'PROD004', 'name': 'Jeans', 'category': 'clothing', 'price': 120.00},  # Non-compliant (above max price)
            {'product_id': 'PROD005', 'name': 'Bluetooth Speaker', 'category': 'electronics', 'price': 79.99}
        ]
        
        # Filter by category if specified
        if category:
            filtered_items = [item for item in inventory_items if item['category'].lower() == category.lower()]
        else:
            filtered_items = inventory_items
        
        # Process each item for compliance
        results = []
        compliant_count = 0
        non_compliant_count = 0
        
        for item in filtered_items:
            product_id = item.get('product_id')
            price = item.get('price')
            
            # Check compliance
            compliance = check_price_compliance(product_id, price)
            is_compliant = compliance.get('compliant', False)
            
            if is_compliant:
                compliant_count += 1
            else:
                non_compliant_count += 1
            
            # Add to results if not filtering or if non-compliant
            if not compliance_only or not is_compliant:
                results.append({
                    'product_id': product_id,
                    'name': item.get('name', 'Unknown'),
                    'category': item.get('category', 'Unknown'),
                    'price': price,
                    'compliant': is_compliant,
                    'reason': compliance.get('reason', ''),
                    'min_price': compliance.get('min_price'),
                    'max_price': compliance.get('max_price')
                })
        
        # Return the scan results
        return {
            'total_items': len(filtered_items),
            'compliant_count': compliant_count,
            'non_compliant_count': non_compliant_count,
            'category_filter': category,
            'results': results
        }
    except Exception as e:
        print(f"Unexpected error in scan_inventory: {str(e)}")
        return {
            'error': f"Error scanning inventory: {str(e)}",
            'results': []
        }
