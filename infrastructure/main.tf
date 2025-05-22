provider "aws" {
  region = var.aws_region
}

provider "awscc" {
  region = var.aws_region
}

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.35.0"
    }
  }
  # Backend configuration is now in backend.tf
}

# Define local variables for Bedrock resources
locals {
  bedrock_agent_name = "${local.name_prefix}-agent"
  bedrock_agent_alias_name = "${local.name_prefix}-agent-alias"
  bedrock_knowledge_base_name = "${local.name_prefix}-kb"
  bedrock_agent_instruction = <<-EOT
    You are an AI assistant for a retail pricing compliance system. Your job is to help users understand pricing policies, 
    analyze inventory data, and ensure pricing compliance with company policies and regulations.
    
    You can use the following tools:
    1. Inventory Scanner - to scan and analyze inventory data
    2. Pricing Tools - to check and update product prices
    
    Always be helpful, concise, and accurate in your responses.
  EOT
  
  inventory_tools_schema = jsonencode({
    "openapi": "3.0.0",
    "info": {
      "title": "Inventory Scanner API",
      "description": "API for scanning and analyzing inventory data",
      "version": "1.0.0"
    },
    "paths": {
      "/scan": {
        "post": {
          "summary": "Scan inventory",
          "description": "Scan inventory data for analysis",
          "operationId": "scanInventory",
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "storeId": {
                      "type": "string",
                      "description": "ID of the store"
                    },
                    "category": {
                      "type": "string",
                      "description": "Product category to scan"
                    }
                  },
                  "required": ["storeId"]
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Successful operation",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object"
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
    "openapi": "3.0.0",
    "info": {
      "title": "Pricing Tools API",
      "description": "API for managing product prices",
      "version": "1.0.0"
    },
    "paths": {
      "/check": {
        "post": {
          "summary": "Check price compliance",
          "description": "Check if product prices comply with policies",
          "operationId": "checkPriceCompliance",
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "productId": {
                      "type": "string",
                      "description": "ID of the product"
                    },
                    "price": {
                      "type": "number",
                      "description": "Current price of the product"
                    }
                  },
                  "required": ["productId", "price"]
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Successful operation",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object"
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

# Random string for unique resource naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  resource_suffix = random_string.suffix.result
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
