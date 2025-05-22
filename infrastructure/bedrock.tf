resource "aws_opensearchserverless_collection" "kb_collection" {
  name = "${local.name_prefix}-kb-collection"
  type = "VECTORSEARCH"
  
  tags = local.common_tags
}

resource "aws_opensearchserverless_security_policy" "kb_encryption" {
  name        = "${local.name_prefix}-kb-encryption"
  type        = "encryption"
  description = "Encryption policy for knowledge base collection"
  
  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection"
        Resource = [
          "collection/${aws_opensearchserverless_collection.kb_collection.name}"
        ]
      }
    ],
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_access_policy" "kb_access" {
  name        = "${local.name_prefix}-kb-access"
  type        = "data"
  description = "Access policy for knowledge base collection"
  
  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection",
        Resource = [
          "collection/${aws_opensearchserverless_collection.kb_collection.name}"
        ],
        Permission = [
          "aoss:CreateCollectionItems",
          "aoss:DeleteCollectionItems",
          "aoss:UpdateCollectionItems",
          "aoss:DescribeCollectionItems"
        ]
      },
      {
        ResourceType = "index",
        Resource = [
          "index/${aws_opensearchserverless_collection.kb_collection.name}/*"
        ],
        Permission = [
          "aoss:CreateIndex",
          "aoss:DeleteIndex",
          "aoss:UpdateIndex",
          "aoss:DescribeIndex",
          "aoss:ReadDocument",
          "aoss:WriteDocument"
        ]
      }
    ],
    Principal = [
      aws_iam_role.ecs_task.arn,
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/bedrock.amazonaws.com/AWSServiceRoleForAmazonBedrockKnowledgeBase"
    ]
  })
}

resource "aws_bedrock_knowledge_base" "pricing_kb" {
  name        = "${local.name_prefix}-kb"
  description = "Knowledge base for pricing policies"
  
  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v1"
    }
  }
  
  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn = aws_opensearchserverless_collection.kb_collection.arn
    }
  }
  
  depends_on = [
    aws_opensearchserverless_security_policy.kb_encryption,
    aws_opensearchserverless_access_policy.kb_access
  ]
  
  tags = local.common_tags
}

resource "aws_bedrock_knowledge_base_data_source" "policy_data_source" {
  knowledge_base_id = aws_bedrock_knowledge_base.pricing_kb.id
  name              = "pricing-policies"
  description       = "Pricing policies data source"
  
  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = aws_s3_bucket.policy.arn
    }
  }
  
  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"
      fixed_size_chunking_configuration {
        max_tokens          = 300
        overlap_percentage  = 10
      }
    }
  }
  
  tags = local.common_tags
}

# Store knowledge base ID in SSM Parameter Store
resource "aws_ssm_parameter" "kb_id" {
  name  = "/${local.name_prefix}/knowledge-base-id"
  type  = "String"
  value = aws_bedrock_knowledge_base.pricing_kb.id
  
  tags = local.common_tags
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
