###########################
# Amazon Bedrock Resources
###########################

# Bedrock Knowledge Base
resource "aws_bedrockagent_knowledge_base" "pricing_policies" {
  name        = "${local.name_prefix}-pricing-policies-kb"
  description = "Knowledge base for pricing policies"
  
  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    
    opensearch_serverless_configuration {
      collection_name = "${local.name_prefix}-pricing-policies-collection"
      vector_field_name = "embedding"
      text_field_name = "text"
      field_mapping {
        field_name = "document_id"
        field_type = "STRING"
      }
      field_mapping {
        field_name = "policy_type"
        field_type = "STRING"
      }
      field_mapping {
        field_name = "category"
        field_type = "STRING"
      }
    }
  }
  
  knowledge_base_configuration {
    type = "VECTOR"
    
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_embedding_model_id}"
    }
  }
  
  role_arn = aws_iam_role.bedrock_service.arn
  
  tags = local.common_tags
}

# Bedrock Knowledge Base Data Source
resource "aws_bedrockagent_data_source" "pricing_policies" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.pricing_policies.id
  name              = "${local.name_prefix}-pricing-policies-data-source"
  description       = "S3 data source for pricing policies"
  
  data_source_configuration {
    type = "S3"
    
    s3_configuration {
      bucket_name = aws_s3_bucket.pricing_policies.bucket
      inclusion_prefixes = ["pricing-policies/"]
    }
  }
  
  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"
      
      fixed_size_chunking_configuration {
        max_tokens = 300
        overlap    = 20
      }
    }
  }
  
  role_arn = aws_iam_role.bedrock_service.arn
}

# Bedrock Agent
resource "aws_bedrockagent_agent" "pricing_agent" {
  name        = "${local.name_prefix}-pricing-agent"
  description = "AI agent for pricing compliance"
  
  foundation_model = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}"
  
  instruction = <<-EOT
    You are a pricing compliance specialist responsible for ensuring all product prices align with company policies.

    Your capabilities:
    1. Access pricing policies via Knowledge Base search
    2. Retrieve current item prices using get_item_price()
    3. Update non-compliant prices using update_price()
    4. Assess individual or bulk item compliance

    When processing requests:
    1. Always check current pricing policies first
    2. Retrieve item details and current prices
    3. Compare against applicable policies
    4. Update prices only when non-compliant
    5. Provide detailed reasoning for all changes

    Response format: Provide summary of actions taken and reasoning for each price change.
  EOT
  
  idle_session_ttl_in_seconds = 1800
  
  role_arn = aws_iam_role.bedrock_service.arn
  
  knowledge_base_associations {
    knowledge_base_id = aws_bedrockagent_knowledge_base.pricing_policies.id
  }
  
  tags = local.common_tags
}

# Inventory Action Group
resource "aws_bedrockagent_agent_action_group" "inventory_tools" {
  agent_id    = aws_bedrockagent_agent.pricing_agent.id
  name        = "InventoryTools"
  description = "Tools for scanning inventory"
  
  action_group_executor {
    lambda {
      lambda_arn = aws_lambda_function.inventory_scanner.arn
    }
  }
  
  action_group_state = "ENABLED"
  
  api_schema = jsonencode({
    openapi = "3.0.0"
    info = {
      title   = "Inventory Tools API"
      version = "1.0.0"
    }
    paths = {
      "/scan_inventory" = {
        post = {
          operationId = "scan_inventory"
          summary     = "Scan inventory for pricing compliance"
          description = "Scans the entire inventory and creates batches for processing"
          requestBody = {
            required = true
            content = {
              "application/json" = {
                schema = {
                  type = "object"
                  properties = {
                    category = {
                      type        = "string"
                      description = "Optional category to filter inventory items"
                    }
                  }
                }
              }
            }
          }
          responses = {
            "200" = {
              description = "Successful operation"
              content = {
                "application/json" = {
                  schema = {
                    type = "object"
                    properties = {
                      batches_created = {
                        type        = "integer"
                        description = "Number of batches created"
                      }
                      total_items = {
                        type        = "integer"
                        description = "Total number of items processed"
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  })
}

# Pricing Tools Action Group
resource "aws_bedrockagent_agent_action_group" "pricing_tools" {
  agent_id    = aws_bedrockagent_agent.pricing_agent.id
  name        = "PricingTools"
  description = "Tools for managing product prices"
  
  action_group_executor {
    lambda {
      lambda_arn = aws_lambda_function.pricing_tools.arn
    }
  }
  
  action_group_state = "ENABLED"
  
  api_schema = jsonencode({
    openapi = "3.0.0"
    info = {
      title   = "Pricing Tools API"
      version = "1.0.0"
    }
    paths = {
      "/get_item_price" = {
        post = {
          operationId = "get_item_price"
          summary     = "Get current price and metadata for an item"
          description = "Retrieves the current price and related information for a specific item"
          requestBody = {
            required = true
            content = {
              "application/json" = {
                schema = {
                  type = "object"
                  properties = {
                    item_id = {
                      type        = "string"
                      description = "Product identifier"
                    }
                  }
                  required = ["item_id"]
                }
              }
            }
          }
          responses = {
            "200" = {
              description = "Successful operation"
              content = {
                "application/json" = {
                  schema = {
                    type = "object"
                    properties = {
                      item_id = {
                        type        = "string"
                        description = "Product identifier"
                      }
                      current_price = {
                        type        = "number"
                        description = "Current price of the item"
                      }
                      category = {
                        type        = "string"
                        description = "Product category"
                      }
                      last_updated = {
                        type        = "string"
                        description = "Last price update timestamp"
                      }
                      cost = {
                        type        = "number"
                        description = "Product cost"
                      }
                      margin_percent = {
                        type        = "number"
                        description = "Current margin percentage"
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "/update_price" = {
        post = {
          operationId = "update_price"
          summary     = "Update item price with audit trail"
          description = "Updates the price of an item and records the reason for the change"
          requestBody = {
            required = true
            content = {
              "application/json" = {
                schema = {
                  type = "object"
                  properties = {
                    item_id = {
                      type        = "string"
                      description = "Product identifier"
                    }
                    new_price = {
                      type        = "number"
                      description = "New price to set"
                    }
                    reason = {
                      type        = "string"
                      description = "AI agent's reasoning for change"
                    }
                  }
                  required = ["item_id", "new_price", "reason"]
                }
              }
            }
          }
          responses = {
            "200" = {
              description = "Successful operation"
              content = {
                "application/json" = {
                  schema = {
                    type = "object"
                    properties = {
                      success = {
                        type        = "boolean"
                        description = "Whether the update was successful"
                      }
                      old_price = {
                        type        = "number"
                        description = "Previous price"
                      }
                      new_price = {
                        type        = "number"
                        description = "Updated price"
                      }
                      updated_at = {
                        type        = "string"
                        description = "Timestamp of the update"
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  })
}

# Bedrock Agent Alias
resource "aws_bedrockagent_agent_alias" "pricing_agent" {
  agent_id    = aws_bedrockagent_agent.pricing_agent.id
  name        = "${local.name_prefix}-pricing-agent-alias"
  description = "Alias for pricing compliance agent"
  
  routing_configuration {
    agent_version = "$LATEST"
  }
  
  tags = local.common_tags
}
