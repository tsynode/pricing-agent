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
  
  # Uncomment this block to use S3 for state management
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "pricing-agent/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

# AWS Bedrock module for managing Bedrock resources
module "bedrock" {
  source  = "aws-ia/bedrock/aws"
  version = "0.0.20"
  
  # Agent configuration
  foundation_model = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}"
  instruction = local.bedrock_agent_instruction
  name = local.name_prefix
  description = "AI agent for pricing compliance"
  
  # Create agent alias
  create_agent_alias = true
  alias_name = "${local.name_prefix}-alias"
  
  # Knowledge base configuration
  create_default_kb = true
  create_s3_data_source = true
  kb_name = "${local.name_prefix}-kb"
  kb_description = "Knowledge base for pricing policies"
  kb_instruction = "Use this knowledge base to answer questions about pricing policies and compliance rules."
  embedding_model = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_embedding_model_id}"
  s3_bucket = aws_s3_bucket.pricing_policies.bucket
  s3_prefix = "pricing-policies/"
  
  # Action group configuration
  create_ag = true
  ag_name = "PricingTools"
  ag_description = "Tools for managing product prices and inventory"
  ag_api_schema = local.pricing_tools_schema
  ag_lambda_arn = aws_lambda_function.pricing_tools.arn
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
