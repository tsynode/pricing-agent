resource "aws_dynamodb_table" "pricing" {
  name         = "${local.name_prefix}-pricing-rules"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "product_id"
  
  attribute {
    name = "product_id"
    type = "S"
  }
  
  # Lifecycle configuration
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      read_capacity,
      write_capacity,
      billing_mode,
      ttl
    ]
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
  
  # Lifecycle configuration
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      read_capacity,
      write_capacity,
      billing_mode,
      ttl
    ]
  }
  
  tags = local.common_tags
}

# Sessions table for agent conversation history persistence
resource "aws_dynamodb_table" "sessions" {
  name         = "${local.name_prefix}-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"
  
  attribute {
    name = "session_id"
    type = "S"
  }
  
  # Enable TTL for automatic session cleanup
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
  
  # Lifecycle configuration
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      read_capacity,
      write_capacity,
      billing_mode,
      ttl
    ]
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

resource "aws_ssm_parameter" "sessions_table_name" {
  name  = "/${local.name_prefix}/sessions-table-name"
  type  = "String"
  value = aws_dynamodb_table.sessions.name
  
  tags = local.common_tags
}

