# Temporarily use a placeholder for the knowledge base ID
# We'll create the knowledge base separately after the initial infrastructure deployment

# Store placeholder knowledge base ID in SSM Parameter Store
resource "aws_ssm_parameter" "kb_id" {
  name  = "/${local.name_prefix}/knowledge-base-id"
  type  = "String"
  value = "placeholder-kb-id"  # This will be updated later with the actual KB ID
  
  tags = local.common_tags
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
