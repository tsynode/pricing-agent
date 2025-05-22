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
  bedrock_knowledge_base_name = "${local.name_prefix}-kb"
}

# Random string for unique resource naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  resource_suffix = random_string.suffix.result
}
