# This S3 bucket is where policy documents are stored for the Bedrock Knowledge Base

resource "aws_s3_bucket" "policy" {
  bucket = "${local.name_prefix}-policies"
  
  # This prevents Terraform from recreating the bucket if it already exists
  # with a slightly different name or configuration
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      bucket,
      server_side_encryption_configuration,
      versioning
      # Removed deprecated 'acl' attribute
    ]
  }
  
  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "policy_versioning" {
  bucket = aws_s3_bucket.policy.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "policy_encryption" {
  bucket = aws_s3_bucket.policy.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Upload initial policy documents
resource "aws_s3_object" "initial_policies" {
  for_each = fileset("${path.module}/../policies", "**/*.txt")
  
  bucket = aws_s3_bucket.policy.id
  key    = each.value
  source = "${path.module}/../policies/${each.value}"
  etag   = filemd5("${path.module}/../policies/${each.value}")
  
  # Prevent conflicts with existing objects
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      etag
    ]
  }
}

# Store policy bucket name in SSM Parameter Store for reference
resource "aws_ssm_parameter" "policy_bucket_name" {
  name  = "/${local.name_prefix}/policy-bucket-name"
  type  = "String"
  value = aws_s3_bucket.policy.id
  
  tags = local.common_tags
}
