terraform {
  backend "s3" {
    bucket  = "pricing-agent-tf-state-tsynode"
    key     = "env:/${terraform.workspace}/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
  
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
