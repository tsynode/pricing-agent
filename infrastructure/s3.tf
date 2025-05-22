resource "aws_s3_bucket" "pricing_policies" {
  bucket = "${local.name_prefix}-pricing-policies-${local.resource_suffix}"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-pricing-policies"
    }
  )
}

resource "aws_s3_bucket_versioning" "pricing_policies" {
  bucket = aws_s3_bucket.pricing_policies.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pricing_policies" {
  bucket = aws_s3_bucket.pricing_policies.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "pricing_policies" {
  bucket = aws_s3_bucket.pricing_policies.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
