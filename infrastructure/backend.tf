# S3 Backend Configuration
# Note: This file uses empty configuration because the actual values
# will be provided during terraform init using the -backend-config flag.
#
# To initialize with S3 backend, follow these steps:
#
# 1. First, create the S3 bucket and DynamoDB table:
#    terraform apply -target=aws_s3_bucket.terraform_state -target=aws_dynamodb_table.terraform_locks
#
# 2. Note the outputs for bucket name and DynamoDB table name
#
# 3. Initialize Terraform with the backend configuration:
#    terraform init \
#      -backend-config="bucket=<output_bucket_name>" \
#      -backend-config="key=pricing-agent/terraform.tfstate" \
#      -backend-config="region=us-east-1" \
#      -backend-config="dynamodb_table=<output_table_name>"
#
# For CI/CD pipelines, these values should be stored in environment variables or secrets.

terraform {
  backend "s3" {
    # Empty configuration - values provided at runtime via -backend-config
  }
}
