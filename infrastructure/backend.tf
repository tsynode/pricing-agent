terraform {
  backend "s3" {
    # These values will be set by the GitHub Actions workflow or CLI parameters
    # bucket = "pricing-agent-terraform-state"
    # key    = "pricing-agent/terraform.tfstate"
    # region = "us-east-1"
    # dynamodb_table = "pricing-agent-terraform-locks"
  }
}
