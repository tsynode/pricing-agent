###########################
# Amazon Bedrock Configuration
###########################

# Use the AWSCC provider to create Bedrock resources directly with Terraform

# Create a Bedrock Knowledge Base
resource "awscc_bedrock_knowledge_base" "pricing_kb" {
  name        = local.bedrock_knowledge_base_name
  description = "Knowledge base for pricing policies and compliance rules"
  
  knowledge_base_configuration = jsonencode({
    type = "VECTOR",
    vectorKnowledgeBaseConfiguration = {
      embeddingModelArn = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_embedding_model_id}"
    }
  })
  
  storage_configuration = jsonencode({
    type = "OPENSEARCH_SERVERLESS",
    opensearchServerlessConfiguration = {
      collectionArn = aws_opensearchserverless_collection.pricing_kb.arn,
      vectorIndexName = "pricing-vector-index",
      fieldMapping = {
        metadataField = "metadata",
        textField = "text",
        vectorField = "vector_embedding"
      }
    }
  })
  
  role_arn = aws_iam_role.bedrock_service.arn
}

# Create an OpenSearch Serverless Collection for the Knowledge Base
resource "aws_opensearchserverless_collection" "pricing_kb" {
  name = "${local.name_prefix}-kb-collection"
  type = "VECTORSEARCH"
}

# Create a Bedrock Agent
resource "awscc_bedrock_agent" "pricing_agent" {
  agent_name  = local.bedrock_agent_name
  description = "AI agent for pricing compliance"
  
  agent_resource_role_arn = aws_iam_role.bedrock_service.arn
  foundation_model       = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}"
  instruction            = local.bedrock_agent_instruction
  
  # Associate the Knowledge Base with the Agent
  knowledge_base_associations = jsonencode([
    {
      knowledgeBaseId = awscc_bedrock_knowledge_base.pricing_kb.id,
      description     = "Pricing policies knowledge base"
    }
  ])
  
  # Create Action Groups for the Agent
  action_groups = jsonencode([
    {
      actionGroupName = "InventoryTools",
      description     = "Tools for scanning inventory",
      actionGroupExecutor = {
        lambda = {
          lambdaArn = aws_lambda_function.inventory_scanner.arn
        }
      },
      apiSchema = local.inventory_tools_schema
    },
    {
      actionGroupName = "PricingTools",
      description     = "Tools for managing product prices",
      actionGroupExecutor = {
        lambda = {
          lambdaArn = aws_lambda_function.pricing_tools.arn
        }
      },
      apiSchema = local.pricing_tools_schema
    }
  ])
}

# Create a Bedrock Agent Alias
resource "awscc_bedrock_agent_alias" "pricing_agent_alias" {
  agent_id    = awscc_bedrock_agent.pricing_agent.id
  alias_name  = local.bedrock_agent_alias_name
  description = "Production alias for pricing agent"
  
  routing_configuration = jsonencode({
    agentVersion = "DRAFT"
  })
}
