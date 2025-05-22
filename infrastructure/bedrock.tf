# Use the AWS-IA Bedrock module for Knowledge Base
module "bedrock" {
  source  = "aws-ia/bedrock/aws"
  version = "0.0.20"
  
  # Create a vector knowledge base with OpenSearch Serverless
  create_default_kb = true
  create_s3_data_source = true
  
  # Knowledge base configuration
  kb_name = "${local.name_prefix}-kb"
  kb_description = "Knowledge base for pricing policies"
  instruction = "You are a pricing compliance agent who can provide detailed information about pricing policies and regulations."
  
  # S3 data source configuration
  s3_data_source_name = "pricing-policies"
  s3_data_source_description = "Pricing policies data source"
  s3_bucket_name = aws_s3_bucket.policy.id
  s3_bucket_arn = aws_s3_bucket.policy.arn
  
  # Chunking configuration
  chunking_strategy = "FIXED_SIZE"
  max_tokens = 300
  overlap_percentage = 10
  
  # Embedding model
  embedding_model = "amazon.titan-embed-text-v1"
  
  # IAM roles
  iam_roles = [aws_iam_role.ecs_task.arn]
  
  # Tags
  tags = local.common_tags
}

# Store knowledge base ID in SSM Parameter Store
resource "aws_ssm_parameter" "kb_id" {
  name  = "/${local.name_prefix}/knowledge-base-id"
  type  = "String"
  value = module.bedrock.knowledge_base_id
  
  tags = local.common_tags
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
