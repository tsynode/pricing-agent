# S3 Backend Configuration
# 
# This empty backend block is configured at runtime with values from:
# - GitHub Actions workflow (for CI/CD)
# - Command line parameters (for local development)

terraform {
  backend "s3" {
    # Empty configuration - values provided at runtime via -backend-config
    # Required parameters:
    # - bucket: S3 bucket name
    # - key: Path to the state file inside the bucket
    # - region: AWS region where the bucket is located
  }
}
