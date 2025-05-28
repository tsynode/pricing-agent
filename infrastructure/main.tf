# AWS Provider configuration is in providers.tf

# Define local variables for consistent naming and tagging across resources
locals {
  name_prefix = var.project_name
  
  # Common tags to be applied to all resources
  common_tags = {
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}
