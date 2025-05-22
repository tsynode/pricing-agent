# S3 Backend Configuration
# 
# This empty backend block is configured at runtime with values from:
# - GitHub Actions workflow (for CI/CD)
# - Command line parameters (for local development)
#
# See README.md in this directory for detailed bootstrap instructions.

terraform {
  backend "s3" {
    # Empty configuration - values provided at runtime via -backend-config
  }
}
