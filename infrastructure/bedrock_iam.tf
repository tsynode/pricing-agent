###########################
# Bedrock IAM Resources
###########################

# IAM policy for Bedrock access
resource "aws_iam_policy" "bedrock_access" {
  name        = "${local.name_prefix}-bedrock-access"
  description = "Policy to allow access to Amazon Bedrock models and knowledge bases"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:ListFoundationModels",
          "bedrock:GetFoundationModel"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_embedding_model_id}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:ListTagsForResource",
          "bedrock:CreateModelCustomizationJob",
          "bedrock:GetModelCustomizationJob",
          "bedrock:StopModelCustomizationJob",
          "bedrock:ListModelCustomizationJobs"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach Bedrock access policy to Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_bedrock_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.bedrock_access.arn
}

# Attach Bedrock access policy to ECS task execution role
resource "aws_iam_role_policy_attachment" "ecs_bedrock_access" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = aws_iam_policy.bedrock_access.arn
}
