###############################################################################
# AMAZON BEDROCK CONFIGURATION
###############################################################################
#
# This file contains all resources related to Amazon Bedrock:
# - Bedrock agent configuration
# - Bedrock knowledge base setup
# - IAM roles and policies for Bedrock access
# - OpenSearch Serverless collection for the knowledge base
#
###############################################################################
# BEDROCK IAM RESOURCES
###############################################################################

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

# Additional S3 permissions for Bedrock service
resource "aws_iam_policy" "bedrock_s3_access" {
  name        = "${local.name_prefix}-bedrock-s3-access"
  description = "S3 access policy for Bedrock service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.pricing_policies.arn,
          "${aws_s3_bucket.pricing_policies.arn}/*"
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

resource "aws_iam_role_policy_attachment" "bedrock_s3_access" {
  role       = aws_iam_role.bedrock_service.name
  policy_arn = aws_iam_policy.bedrock_s3_access.arn
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

# Bedrock foundation model ARNs are constructed directly using the model IDs
# Format: arn:aws:bedrock:{region}::foundation-model/{model_id}

# Create an OpenSearch Serverless Collection for the Knowledge Base
resource "aws_opensearchserverless_collection" "pricing_kb" {
  name = "${local.name_prefix}-kb-collection"
  type = "VECTORSEARCH"
  
  tags = local.common_tags
}

# Create an OpenSearch Serverless access policy
resource "aws_opensearchserverless_access_policy" "pricing_kb_policy" {
  name        = "${local.name_prefix}-kb-access-policy"
  type        = "data"
  description = "Access policy for pricing knowledge base collection"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = [aws_opensearchserverless_collection.pricing_kb.arn]
          Permission   = [
            "aoss:CreateCollectionItems",
            "aoss:DeleteCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DescribeCollectionItems"
          ]
        },
        {
          ResourceType = "index"
          Resource     = ["${aws_opensearchserverless_collection.pricing_kb.arn}/*"]
          Permission   = [
            "aoss:ReadDocument",
            "aoss:WriteDocument",
            "aoss:UpdateDocument",
            "aoss:DeleteDocument"
          ]
        }
      ]
      Principal = [aws_iam_role.bedrock_service.arn]
    }
  ])
}

# Create CloudWatch Log Group for Knowledge Base
resource "aws_cloudwatch_log_group" "knowledge_base_logs" {
  name              = "/aws/bedrock/knowledge-bases/${local.bedrock_knowledge_base_name}"
  retention_in_days = 14
  
  tags = local.common_tags
}

# Create a Bedrock Knowledge Base
resource "awscc_bedrock_knowledge_base" "pricing_kb" {
  name        = local.bedrock_knowledge_base_name
  description = "Knowledge base for pricing policies and compliance rules"
  
  knowledge_base_configuration = {
    type = "VECTOR"
    vector_knowledge_base_configuration = {
      embedding_model_arn = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_embedding_model_id}"
    }
  }
  
  storage_configuration = {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration = {
      collection_arn = aws_opensearchserverless_collection.pricing_kb.arn
      vector_index_name = "pricing-vector-index"
      field_mapping = {
        metadata_field = "metadata"
        text_field = "text"
        vector_field = "vector_embedding"
      }
    }
  }
  
  role_arn = aws_iam_role.bedrock_service.arn

  depends_on = [
    aws_opensearchserverless_access_policy.pricing_kb_policy,
    aws_cloudwatch_log_group.knowledge_base_logs
  ]
}

# Create a Bedrock Agent
resource "awscc_bedrock_agent" "pricing_agent" {
  agent_name  = local.bedrock_agent_name
  description = "AI agent for pricing compliance"
  
  agent_resource_role_arn = aws_iam_role.bedrock_service.arn
  foundation_model       = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}"
  instruction            = local.bedrock_agent_instruction
  
  # Create Action Groups for the Agent
  action_groups = [
    {
      action_group_name = "InventoryTools"
      description     = "Tools for scanning inventory"
      action_group_executor = {
        lambda = {
          lambda_arn = aws_lambda_function.inventory_scanner.arn
        }
      }
      api_schema = local.inventory_tools_schema
    },
    {
      action_group_name = "PricingTools"
      description     = "Tools for managing product prices"
      action_group_executor = {
        lambda = {
          lambda_arn = aws_lambda_function.pricing_tools.arn
        }
      }
      api_schema = local.pricing_tools_schema
    }
  ]
  
  # Associate the knowledge base with the agent
  knowledge_base_associations = [
    {
      knowledge_base_id = awscc_bedrock_knowledge_base.pricing_kb.id
      description = "Knowledge base for pricing policies and compliance"
    }
  ]
}

# Create a Bedrock Agent Alias
resource "awscc_bedrock_agent_alias" "pricing_agent_alias" {
  agent_id    = awscc_bedrock_agent.pricing_agent.id
  alias_name  = local.bedrock_agent_alias_name
  description = "Production alias for pricing agent"
  
  routing_configuration = {
    agent_version = "DRAFT"
  }
}

# Add Lambda permission for Bedrock Agent
resource "aws_lambda_permission" "allow_bedrock_agent_inventory" {
  statement_id  = "AllowBedrockAgentInventoryInvocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.inventory_scanner.function_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = awscc_bedrock_agent.pricing_agent.arn
}

resource "aws_lambda_permission" "allow_bedrock_agent_pricing" {
  statement_id  = "AllowBedrockAgentPricingInvocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pricing_tools.function_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = awscc_bedrock_agent.pricing_agent.arn
}
