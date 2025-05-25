# AWS Provider configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Define local variables for consistent naming and tagging across resources
locals {
  # Using environment variable for consistent, idempotent naming across deployments
  # This ensures resources are reused rather than recreated with each deployment
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Common tags to be applied to all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    DeployedAt  = timestamp()
  }
}
