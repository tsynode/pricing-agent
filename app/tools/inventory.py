"""
Inventory tools for the Strands Agents SDK
"""
from strands import tool
import boto3
import os
from .pricing import check_price_compliance

# Initialize clients
dynamodb = boto3.resource('dynamodb')
inventory_table = dynamodb.Table(os.environ.get('INVENTORY_TABLE_NAME', 'inventory'))

@tool
def scan_inventory(category: str = None, compliance_only: bool = False) -> dict:
    """Scan inventory for pricing issues
    
    Args:
        category: Optional category to filter the scan
        compliance_only: If True, only return non-compliant items
        
    Returns:
        A dictionary with scan results
    """
    try:
        # Hardcoded inventory data for demo purposes
        inventory_items = [
            # Electronics - some with compliance issues
            {'product_id': 'PROD001', 'name': 'Premium Headphones', 'category': 'electronics', 'price': 149.99},
            {'product_id': 'PROD002', 'name': 'Phone Charger', 'category': 'electronics', 'price': 15.99},  # Non-compliant (below min price)
            {'product_id': 'PROD005', 'name': '4K Smart TV', 'category': 'electronics', 'price': 899.99},
            {'product_id': 'PROD006', 'name': 'Gaming Console', 'category': 'electronics', 'price': 499.99},
            {'product_id': 'PROD007', 'name': 'Tablet', 'category': 'electronics', 'price': 299.99},
            {'product_id': 'PROD008', 'name': 'Wireless Earbuds', 'category': 'electronics', 'price': 75.99},  # Non-compliant (below min price)
            
            # Clothing - some with compliance issues
            {'product_id': 'PROD003', 'name': 'Designer T-Shirt', 'category': 'clothing', 'price': 45.99},
            {'product_id': 'PROD004', 'name': 'Jeans', 'category': 'clothing', 'price': 120.00},  # Non-compliant (above max price)
            {'product_id': 'PROD009', 'name': 'Winter Jacket', 'category': 'clothing', 'price': 89.99},
            {'product_id': 'PROD010', 'name': 'Dress Shoes', 'category': 'clothing', 'price': 59.99},
            {'product_id': 'PROD011', 'name': 'Formal Shirt', 'category': 'clothing', 'price': 39.99},
            {'product_id': 'PROD012', 'name': 'Casual Shorts', 'category': 'clothing', 'price': 24.99},
            
            # Home goods - all compliant
            {'product_id': 'PROD013', 'name': 'Coffee Machine', 'category': 'home', 'price': 199.99},
            {'product_id': 'PROD014', 'name': 'Blender Set', 'category': 'home', 'price': 129.99},
            {'product_id': 'PROD015', 'name': 'Bedding Set', 'category': 'home', 'price': 79.99},
            {'product_id': 'PROD016', 'name': 'Towel Set', 'category': 'home', 'price': 49.99},
            
            # Fresh produce - some with compliance issues
            {'product_id': 'PROD017', 'name': 'Fresh Bread (Loaf)', 'category': 'fresh_produce', 'price': 4.50},
            {'product_id': 'PROD018', 'name': 'Milk (1 Gallon)', 'category': 'fresh_produce', 'price': 3.99},
            {'product_id': 'PROD019', 'name': 'Fresh Strawberries', 'category': 'fresh_produce', 'price': 5.99},
            {'product_id': 'PROD020', 'name': 'Bananas (Bunch)', 'category': 'fresh_produce', 'price': 1.79},
            {'product_id': 'PROD021', 'name': 'Fresh Fish Fillet', 'category': 'fresh_produce', 'price': 9.99},  # Non-compliant (above max price)
            {'product_id': 'PROD022', 'name': 'Yogurt (32oz)', 'category': 'fresh_produce', 'price': 3.49},
            {'product_id': 'PROD023', 'name': 'Fresh Eggs (Dozen)', 'category': 'fresh_produce', 'price': 2.49},
            {'product_id': 'PROD024', 'name': 'Fresh Cheese', 'category': 'fresh_produce', 'price': 6.99}
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
        print(f"Error in scan_inventory: {str(e)}")
        # Provide a fallback response even if there's an error
        return {
            'error': f"Error scanning inventory: {str(e)}",
            'total_items': 0,
            'compliant_count': 0,
            'non_compliant_count': 0,
            'category_filter': category,
            'results': []
        }
