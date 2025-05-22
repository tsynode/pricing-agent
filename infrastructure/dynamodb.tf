resource "aws_dynamodb_table" "pricing" {
  name         = "${local.name_prefix}-pricing-rules"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "product_id"
  
  attribute {
    name = "product_id"
    type = "S"
  }
  
  tags = local.common_tags
}

resource "aws_dynamodb_table" "inventory" {
  name         = "${local.name_prefix}-inventory"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "product_id"
  
  attribute {
    name = "product_id"
    type = "S"
  }
  
  tags = local.common_tags
}

# Store table names in SSM Parameter Store for reference
resource "aws_ssm_parameter" "pricing_table_name" {
  name  = "/${local.name_prefix}/pricing-table-name"
  type  = "String"
  value = aws_dynamodb_table.pricing.name
  
  tags = local.common_tags
}

resource "aws_ssm_parameter" "inventory_table_name" {
  name  = "/${local.name_prefix}/inventory-table-name"
  type  = "String"
  value = aws_dynamodb_table.inventory.name
  
  tags = local.common_tags
}

# Sample data for pricing rules
resource "aws_dynamodb_table_item" "sample_pricing_rules" {
  count = 3
  
  table_name = aws_dynamodb_table.pricing.name
  hash_key   = aws_dynamodb_table.pricing.hash_key
  
  item = jsonencode(
    element(
      [
        {
          product_id = { S = "P1001" }
          min_price  = { N = "9.99" }
          max_price  = { N = "19.99" }
          category   = { S = "Electronics" }
        },
        {
          product_id = { S = "P1002" }
          min_price  = { N = "14.99" }
          max_price  = { N = "29.99" }
          category   = { S = "Electronics" }
        },
        {
          product_id = { S = "P2001" }
          min_price  = { N = "19.99" }
          max_price  = { N = "39.99" }
          category   = { S = "Clothing" }
        }
      ],
      count.index
    )
  )
}

# Sample data for inventory
resource "aws_dynamodb_table_item" "sample_inventory" {
  count = 3
  
  table_name = aws_dynamodb_table.inventory.name
  hash_key   = aws_dynamodb_table.inventory.hash_key
  
  item = jsonencode(
    element(
      [
        {
          product_id = { S = "P1001" }
          name       = { S = "Basic Headphones" }
          price      = { N = "12.99" }
          category   = { S = "Electronics" }
        },
        {
          product_id = { S = "P1002" }
          name       = { S = "Wireless Mouse" }
          price      = { N = "24.99" }
          category   = { S = "Electronics" }
        },
        {
          product_id = { S = "P2001" }
          name       = { S = "Cotton T-Shirt" }
          price      = { N = "15.99" }
          category   = { S = "Clothing" }
        }
      ],
      count.index
    )
  )
}
