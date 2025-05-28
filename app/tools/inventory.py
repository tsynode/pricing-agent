"""
Inventory tools for the Strands Agents SDK
"""
from strands import tool
import boto3
import os
from .pricing import check_price_compliance

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
    try:
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
        return {
            'error': f"Error scanning inventory: {str(e)}",
            'results': []
        }
