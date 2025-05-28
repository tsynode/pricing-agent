# Bedrock Knowledge Base Configuration
# The Knowledge Base itself is managed outside of Terraform for simplicity
# This file contains only the essential supporting infrastructure

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# 1. OPENSEARCH SERVERLESS RESOURCES
# -------------------------------

# Create OpenSearch Serverless Collection for the knowledge base vector store
resource "aws_opensearchserverless_collection" "kb_collection" {
  name = "${local.name_prefix}-kb-coll"
  type = "VECTORSEARCH"
  
  # Wait for security policies to be created first
  depends_on = [
    aws_opensearchserverless_security_policy.encryption_policy,
    aws_opensearchserverless_security_policy.network_policy
  ]

  # Lifecycle configuration
  lifecycle {
    prevent_destroy = false
  }

  tags = local.common_tags
}

# Create encryption policy for OpenSearch Serverless
resource "aws_opensearchserverless_security_policy" "encryption_policy" {
  name = "${local.name_prefix}-enc-pol"
  type = "encryption"
  description = "Encryption policy for OpenSearch Serverless collection"
  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection",
        Resource = ["collection/${local.name_prefix}-kb-coll"]
      }
    ],
    AWSOwnedKey = true
  })
}

# Create network policy for OpenSearch Serverless
resource "aws_opensearchserverless_security_policy" "network_policy" {
  name = "${local.name_prefix}-net-pol"
  type = "network"
  description = "Network policy for OpenSearch Serverless collection"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection",
          Resource = ["collection/${local.name_prefix}-kb-coll"]
        }
      ],
      AllowFromPublic = true
    }
  ])
}

# 2. IAM RESOURCES FOR KNOWLEDGE BASE
# -------------------------------

# Create IAM role for the knowledge base
resource "aws_iam_role" "kb_role" {
  name = "${local.name_prefix}-kb-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        ArnLike = { "aws:SourceArn" = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*" }
      }
    }]
  })
  
  # Lifecycle configuration
  lifecycle { prevent_destroy = false }
  
  tags = local.common_tags
}

# Create policy for OpenSearch Serverless access
resource "aws_iam_policy" "kb_opensearch_policy" {
  name        = "${local.name_prefix}-kb-opensearch-policy"
  description = "Policy for Bedrock Knowledge Base to access OpenSearch Serverless"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["aoss:APIAccessAll"]
      Resource = [aws_opensearchserverless_collection.kb_collection.arn]
    }]
  })
  
  tags = local.common_tags
}

# Create policy for S3 access
resource "aws_iam_policy" "kb_s3_policy" {
  name        = "${local.name_prefix}-kb-s3-policy"
  description = "Policy for Bedrock Knowledge Base to access S3 buckets"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.policy.arn]
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = ["${aws_s3_bucket.policy.arn}/*"]
      }
    ]
  })
  
  tags = local.common_tags
}

# Create policy for Bedrock foundation model access
resource "aws_iam_policy" "kb_foundation_model_policy" {
  name        = "${local.name_prefix}-kb-foundation-model-policy"
  description = "Policy for Bedrock Knowledge Base to access foundation models"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["bedrock:InvokeModel"]
      Resource = ["arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2:0"]
    }]
  })
  
  tags = local.common_tags
}

# Attach policies to the role
resource "aws_iam_role_policy_attachment" "kb_opensearch" {
  role       = aws_iam_role.kb_role.name
  policy_arn = aws_iam_policy.kb_opensearch_policy.arn
}

resource "aws_iam_role_policy_attachment" "kb_s3" {
  role       = aws_iam_role.kb_role.name
  policy_arn = aws_iam_policy.kb_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "kb_foundation_model" {
  role       = aws_iam_role.kb_role.name
  policy_arn = aws_iam_policy.kb_foundation_model_policy.arn
}

# 3. SSM PARAMETER FOR KNOWLEDGE BASE ID
# -------------------------------

# SSM Parameter to store the Knowledge Base ID
# This is managed outside of Terraform but referenced by the sync script
resource "aws_ssm_parameter" "kb_id" {
  name  = "/${local.name_prefix}/knowledge-base-id"
  type  = "String"
  value = "placeholder-to-be-updated-manually"
  
  lifecycle {
    prevent_destroy = false
    ignore_changes = [value]
  }
  
  tags = local.common_tags
}
