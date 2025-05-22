###########################
# Amazon Bedrock Configuration
###########################

# Instead of creating Bedrock resources directly with Terraform,
# we'll define local variables to store the resource information
# and use them in other resources like Lambda and ECS

locals {
  # Bedrock model ARNs
  bedrock_model_arn = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}"
  bedrock_embedding_model_arn = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_embedding_model_id}"
  
  # Bedrock resource names (to be created manually or via script)
  bedrock_knowledge_base_name = "${local.name_prefix}-pricing-policies-kb"
  bedrock_agent_name = "${local.name_prefix}-pricing-agent"
  bedrock_agent_alias_name = "${local.name_prefix}-pricing-agent-alias"
  
  # Bedrock agent instruction
  bedrock_agent_instruction = <<-EOT
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
  
  # API schemas for action groups (to be used in manual creation or scripts)
  inventory_tools_schema = jsonencode({
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
  
  pricing_tools_schema = jsonencode({
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
