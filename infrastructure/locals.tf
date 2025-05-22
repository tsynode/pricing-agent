###############################################################################
# LOCAL VARIABLES
###############################################################################
#
# This file contains all local variables used across the Terraform configuration
#

locals {
  # Create a consistent naming prefix for all resources
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Define common tags to be applied to all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
  
  # Bedrock agent alias name
  bedrock_agent_alias_name = "${local.name_prefix}-alias"
  
  # Bedrock agent instruction
  bedrock_agent_instruction = <<-EOT
    You are a pricing compliance agent that helps ensure products are priced correctly
    according to company policies and regulations. You can:
    
    1. Scan inventory data to identify pricing issues
    2. Check if a specific product's price complies with policies
    3. Explain pricing policies to users
    4. Recommend corrective actions for non-compliant prices
    
    Always be helpful, clear, and accurate in your responses.
  EOT
  
  # OpenAPI schema for inventory tools
  inventory_tools_schema = jsonencode({
    openapi = "3.0.0"
    info = {
      title       = "Inventory Scanner API"
      description = "API for scanning and analyzing inventory data"
      version     = "1.0.0"
    }
    paths = {
      "/scan" = {
        post = {
          summary     = "Scan inventory"
          description = "Scan inventory data for analysis"
          operationId = "scanInventory"
          requestBody = {
            required = true
            content = {
              "application/json" = {
                schema = {
                  type = "object"
                  properties = {
                    storeId = {
                      type        = "string"
                      description = "ID of the store"
                    }
                    category = {
                      type        = "string"
                      description = "Product category to scan"
                    }
                  }
                  required = ["storeId"]
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
                  }
                }
              }
            }
          }
        }
      }
    }
  })
  
  # OpenAPI schema for pricing tools
  pricing_tools_schema = jsonencode({
    openapi = "3.0.0"
    info = {
      title       = "Pricing Tools API"
      description = "API for managing product prices"
      version     = "1.0.0"
    }
    paths = {
      "/check" = {
        post = {
          summary     = "Check price compliance"
          description = "Check if product prices comply with policies"
          operationId = "checkPriceCompliance"
          requestBody = {
            required = true
            content = {
              "application/json" = {
                schema = {
                  type = "object"
                  properties = {
                    productId = {
                      type        = "string"
                      description = "ID of the product"
                    }
                    price = {
                      type        = "number"
                      description = "Current price of the product"
                    }
                  }
                  required = ["productId", "price"]
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
