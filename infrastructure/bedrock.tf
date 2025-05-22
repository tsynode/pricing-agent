# Use the AWS-IA Bedrock module for Knowledge Base
module "bedrock" {
  source  = "aws-ia/bedrock/aws"
  version = "0.0.20"
  
  # Minimal configuration for testing
  create_default_kb = true
  
  # Knowledge base configuration
  kb_name = "${local.name_prefix}-kb"
  
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
