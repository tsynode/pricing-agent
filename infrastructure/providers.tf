terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.86.0"  # Using latest stable version
    }
  }
  
  # Hardcoded S3 backend configuration for simplicity
  backend "s3" {
    bucket = "pricing-agent-tf-state"
    key    = "terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }
  
  required_version = ">= 1.0.0"
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Define local variables for consistent naming and tagging across resources
locals {
  name_prefix = var.project_name
  
  # Common tags to be applied to all resources
  common_tags = {
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}
