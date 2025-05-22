###########################
# Bedrock IAM Resources
###########################

# IAM role for Bedrock service
resource "aws_iam_role" "bedrock_service" {
  name = "${local.name_prefix}-bedrock-service-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "bedrock.amazonaws.com",
            "aoss.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  
  tags = local.common_tags
}

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
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:ListTagsForResource",
          "bedrock:CreateModelCustomizationJob",
          "bedrock:GetModelCustomizationJob",
          "bedrock:StopModelCustomizationJob",
          "bedrock:ListModelCustomizationJobs",
          "bedrock:ListAgents",
          "bedrock:GetAgent",
          "bedrock:ListAgentAliases",
          "bedrock:GetAgentAlias",
          "bedrock:ListAgentActionGroups",
          "bedrock:GetAgentActionGroup",
          "bedrock:InvokeAgent",
          "bedrock:Retrieve",
          "bedrock:ListKnowledgeBases",
          "bedrock:GetKnowledgeBase"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM policy for Bedrock knowledge base access
resource "aws_iam_policy" "bedrock_kb_policy" {
  name        = "${local.name_prefix}-bedrock-kb-policy"
  description = "Policy for Bedrock knowledge base access"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aoss:APIAccessAll",
          "aoss:BatchGetCollection",
          "aoss:BatchGetVectorEnrichmentPolicy",
          "aoss:CreateCollection",
          "aoss:CreateSecurityPolicy",
          "aoss:CreateVectorEnrichmentPolicy",
          "aoss:DeleteCollection",
          "aoss:GetPoliciesStats",
          "aoss:GetSecurityPolicy",
          "aoss:ListCollections",
          "aoss:ListSecurityPolicies",
          "aoss:ListVectorEnrichmentPolicies",
          "aoss:UpdateCollection",
          "aoss:UpdateSecurityPolicy",
          "aoss:UpdateVectorEnrichmentPolicy"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.inventory_scanner.arn,
          aws_lambda_function.pricing_tools.arn
        ]
      }
    ]
  })
}

# Attach policies to Bedrock service role
resource "aws_iam_role_policy_attachment" "bedrock_service_access" {
  role       = aws_iam_role.bedrock_service.name
  policy_arn = aws_iam_policy.bedrock_access.arn
}

resource "aws_iam_role_policy_attachment" "bedrock_service_kb" {
  role       = aws_iam_role.bedrock_service.name
  policy_arn = aws_iam_policy.bedrock_kb_policy.arn
}

# Attach Bedrock access policy to Lambda roles
resource "aws_iam_role_policy_attachment" "inventory_scanner_bedrock_access" {
  role       = aws_iam_role.inventory_scanner_lambda.name
  policy_arn = aws_iam_policy.bedrock_access.arn
}

resource "aws_iam_role_policy_attachment" "pricing_tools_bedrock_access" {
  role       = aws_iam_role.pricing_tools_lambda.name
  policy_arn = aws_iam_policy.bedrock_access.arn
}

# Attach Bedrock access policy to ECS task execution role
resource "aws_iam_role_policy_attachment" "ecs_bedrock_access" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = aws_iam_policy.bedrock_access.arn
}
