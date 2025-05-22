resource "aws_dynamodb_table" "product_financials" {
  name           = "${local.name_prefix}-product-financials"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "item_id"

  attribute {
    name = "item_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-product-financials"
    }
  )
}

resource "aws_dynamodb_table" "inventory" {
  name           = "${local.name_prefix}-inventory"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "item_id"

  attribute {
    name = "item_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-inventory"
    }
  )
}
