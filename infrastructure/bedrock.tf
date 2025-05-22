###########################
# Amazon Bedrock Configuration
###########################

# Data source to get the Bedrock foundation model details
data "aws_bedrock_foundation_model" "agent_model" {
  model_identifier = var.bedrock_model_id
}

data "aws_bedrock_foundation_model" "embedding_model" {
  model_identifier = var.bedrock_embedding_model_id
}

# Create an OpenSearch Serverless Collection for the Knowledge Base
resource "aws_opensearchserverless_collection" "pricing_kb" {
  name = "${local.name_prefix}-kb-collection"
  type = "VECTORSEARCH"
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
}

# Create a Bedrock Knowledge Base
resource "awscc_bedrock_knowledge_base" "pricing_kb" {
  name        = local.bedrock_knowledge_base_name
  description = "Knowledge base for pricing policies and compliance rules"
  
  knowledge_base_configuration = {
    type = "VECTOR"
    vector_knowledge_base_configuration = {
      embedding_model_arn = data.aws_bedrock_foundation_model.embedding_model.arn
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
  foundation_model       = data.aws_bedrock_foundation_model.agent_model.arn
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
  statement_id  = "AllowBedrockAgentInvocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.inventory_scanner.function_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = awscc_bedrock_agent.pricing_agent.arn
}

resource "aws_lambda_permission" "allow_bedrock_agent_pricing" {
  statement_id  = "AllowBedrockAgentInvocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pricing_tools.function_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = awscc_bedrock_agent.pricing_agent.arn
}
