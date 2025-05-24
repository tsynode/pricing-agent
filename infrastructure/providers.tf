terraform {
  # S3 backend is configured dynamically in the GitHub Actions workflow
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31.0"  # Specify a stable version
    }
  }
  
  required_version = ">= 1.0.0"
}
