# Store the Bedrock knowledge base ID in SSM Parameter Store
resource "aws_ssm_parameter" "kb_id" {
  name  = "/${local.name_prefix}/knowledge-base-id"
  type  = "String"
  value = "QN1JGEFGJ0"  # Actual knowledge base ID
  
  # Prevent conflicts with existing parameter
  lifecycle {
    ignore_changes = [
      value
    ]
  }
  
  tags = local.common_tags
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
