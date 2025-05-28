terraform {
  # S3 backend is configured dynamically in the GitHub Actions workflow
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.86.0"  # Using latest stable version
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.0"
    }
  }
  
  required_version = ">= 1.0.0"
}
