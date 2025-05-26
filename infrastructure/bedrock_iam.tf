# IAM role for managing Bedrock resources
resource "aws_iam_role" "bedrock_management" {
  name = "${local.name_prefix}-bedrock-management-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}

# IAM policy for managing Bedrock inference profiles
resource "aws_iam_policy" "bedrock_management_policy" {
  name        = "${local.name_prefix}-bedrock-management-policy"
  description = "Policy for managing Bedrock inference profiles"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:CreateInferenceProfile",
          "bedrock:GetInferenceProfile",
          "bedrock:UpdateInferenceProfile",
          "bedrock:DeleteInferenceProfile",
          "bedrock:ListInferenceProfiles",
          "bedrock:TagResource",
          "bedrock:UntagResource",
          "bedrock:ListTagsForResource"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:inference-profile/*"
        ]
      }
    ]
  })
  
  tags = local.common_tags
}

# Attach the Bedrock management policy to the role
resource "aws_iam_role_policy_attachment" "bedrock_management" {
  role       = aws_iam_role.bedrock_management.name
  policy_arn = aws_iam_policy.bedrock_management_policy.arn
}

# Add Bedrock management permissions to the ECS task role
resource "aws_iam_policy" "ecs_bedrock_policy" {
  name        = "${local.name_prefix}-ecs-bedrock-policy"
  description = "Additional Bedrock permissions for ECS task role"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:CreateInferenceProfile",
          "bedrock:GetInferenceProfile",
          "bedrock:UpdateInferenceProfile",
          "bedrock:ListInferenceProfiles"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:inference-profile/*"
        ]
      }
    ]
  })
  
  tags = local.common_tags
}

# Attach the additional Bedrock permissions to the ECS task role
resource "aws_iam_role_policy_attachment" "ecs_bedrock" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.ecs_bedrock_policy.arn
}
