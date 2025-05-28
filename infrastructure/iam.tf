# Note: aws_caller_identity data source is defined in bedrock_kb.tf

resource "aws_iam_role" "ecs_execution" {
  name = "${local.name_prefix}-ecs-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  
  # Lifecycle configuration
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      assume_role_policy,
      max_session_duration,
      permissions_boundary
    ]
  }
  
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name = "${local.name_prefix}-ecs-task-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  
  # Lifecycle configuration
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      assume_role_policy,
      max_session_duration,
      permissions_boundary
    ]
  }
  
  tags = local.common_tags
}

resource "aws_iam_policy" "ecs_task_policy" {
  name        = "${local.name_prefix}-ecs-task-policy"
  description = "Policy for ECS task role"
  
  # Lifecycle configuration
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      description
    ]
  }
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.policy.arn,
          "${aws_s3_bucket.policy.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          aws_dynamodb_table.pricing.arn,
          aws_dynamodb_table.inventory.arn,
          aws_dynamodb_table.sessions.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:*:parameter/${local.name_prefix}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:Retrieve"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/*",
          "arn:aws:bedrock:us-east-2::foundation-model/*",
          "arn:aws:bedrock:us-west-2::foundation-model/*",
          "arn:aws:bedrock:${var.aws_region}:*:knowledge-base/*",
          "arn:aws:bedrock:us-east-2:*:knowledge-base/*",
          "arn:aws:bedrock:us-west-2:*:knowledge-base/*",
          # Using Claude 3 Haiku which supports on-demand throughput
        ]
      }
    ]
  })
  
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}
