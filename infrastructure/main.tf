provider "aws" {
  region = var.aws_region
}

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Uncomment this block to use Terraform Cloud for state management
  # backend "remote" {
  #   organization = "your-org-name"
  #   workspaces {
  #     name = "pricing-agent"
  #   }
  # }
}

# AWS Bedrock module for managing Bedrock resources
module "bedrock" {
  source  = "aws-ia/bedrock/aws"
  version = "0.0.13"
  
  # Agent configuration
  create_agent = true
  agent_name = local.name_prefix
  agent_description = "AI agent for pricing compliance"
  agent_instruction = local.bedrock_agent_instruction
  foundation_model = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}"
  
  # Knowledge base configuration
  create_knowledge_base = true
  knowledge_base_name = "${local.name_prefix}-kb"
  knowledge_base_description = "Knowledge base for pricing policies"
  knowledge_base_role_name = "${local.name_prefix}-kb-role"
  embedding_model_arn = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_embedding_model_id}"
  
  # S3 configuration for knowledge base
  s3_bucket_name = aws_s3_bucket.pricing_policies.bucket
  s3_prefix = "pricing-policies/"
  
  # Action groups
  action_groups = [
    {
      name = "InventoryTools"
      description = "Tools for scanning inventory"
      api_schema = local.inventory_tools_schema
      action_group_executor = {
        lambda = {
          lambda_arn = aws_lambda_function.inventory_scanner.arn
        }
      }
    },
    {
      name = "PricingTools"
      description = "Tools for managing product prices"
      api_schema = local.pricing_tools_schema
      action_group_executor = {
        lambda = {
          lambda_arn = aws_lambda_function.pricing_tools.arn
        }
      }
    }
  ]
}
  
  # Uncomment this block to use Terraform Cloud for state management
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "pricing-agent/terraform.tfstate"
  #   region = "us-east-1"
  # }
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
