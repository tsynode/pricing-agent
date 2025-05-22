# Use the AWS-IA Bedrock module for Knowledge Base
module "bedrock" {
  source  = "aws-ia/bedrock/aws"
  version = "0.0.24"  # Updated to latest version
  
  # Required foundation model for IAM policies
  foundation_model = "us.anthropic.claude-3-7-sonnet-20250219-v1:0"
  
  # Knowledge base configuration - minimal required settings
  create_default_kb = true
  create_agent = false
  create_s3_data_source = true
  
  # Knowledge base name
  kb_name = "${local.name_prefix}-kb"
  
  # S3 data source configuration
  kb_s3_data_source = aws_s3_bucket.policy.arn
  
  # Tags
  tags = local.common_tags
}

# Store knowledge base ID in SSM Parameter Store
resource "aws_ssm_parameter" "kb_id" {
  name  = "/${local.name_prefix}/knowledge-base-id"
  type  = "String"
  value = module.bedrock.default_kb_identifier
  
  tags = local.common_tags
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
