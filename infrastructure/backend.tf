# S3 Backend Configuration
# Note: This file uses empty configuration because the actual values
# will be provided during terraform init using the -backend-config flag.
#
# BOOTSTRAP PROCESS:
# The first time you set up the S3 backend, you need to follow these steps:
#
# 1. Temporarily comment out the backend configuration:
#    terraform {
#      # backend "s3" {}
#    }
#
# 2. Initialize Terraform with local backend:
#    terraform init
#
# 3. Create the S3 bucket and DynamoDB table:
#    terraform apply -target=aws_s3_bucket.terraform_state -target=aws_dynamodb_table.terraform_locks
#
# 4. Note the outputs for bucket name and DynamoDB table name
#
# 5. Uncomment the backend configuration and initialize with S3 backend:
#    terraform init -force-copy \
#      -backend-config="bucket=<output_bucket_name>" \
#      -backend-config="key=pricing-agent/terraform.tfstate" \
#      -backend-config="region=us-east-1" \
#      -backend-config="dynamodb_table=<output_table_name>"
#
# For CI/CD pipelines, this process is automated in the GitHub workflow.

terraform {
  backend "s3" {
    # Empty configuration - values provided at runtime via -backend-config
  }
}
