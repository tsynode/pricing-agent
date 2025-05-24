# QUARANTINED: Session bucket resources - May 2025
# These resources appear to be unused by the application.
# Keeping them commented out to see if the application functions without them.
# If no issues arise, these can be safely removed in a future update.

/*
resource "aws_s3_bucket" "session" {
  bucket = "${local.name_prefix}-sessions-${random_string.suffix.result}"
  
  # This prevents Terraform from recreating the bucket if it already exists
  # with a slightly different name or configuration
  lifecycle {
    ignore_changes = [
      bucket,
      server_side_encryption_configuration,
      versioning
    ]
  }
  
  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "session_versioning" {
  bucket = aws_s3_bucket.session.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "session_encryption" {
  bucket = aws_s3_bucket.session.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "session_lifecycle" {
  bucket = aws_s3_bucket.session.id
  
  rule {
    id     = "expire-old-sessions"
    status = "Enabled"
    
    filter {
      prefix = ""
    }
    
    expiration {
      days = 30
    }
  }
}
*/

resource "aws_s3_bucket" "policy" {
  bucket = "${local.name_prefix}-policies"
  
  # This prevents Terraform from recreating the bucket if it already exists
  # with a slightly different name or configuration
  lifecycle {
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
