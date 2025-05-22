terraform {
  # Uncomment this block to use Terraform Cloud for state management
  # cloud {
  #   organization = "your-organization"
  #   workspaces {
  #     name = "pricing-agent-${var.environment}"
  #   }
  # }
  
  # Alternatively, use S3 backend for state management
  # backend "s3" {
  #   bucket         = "terraform-state-bucket-name"
  #   key            = "pricing-agent/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31.0"  # Specify a stable version
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  
  required_version = ">= 1.0.0"
}
