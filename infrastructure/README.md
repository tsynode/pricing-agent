# Pricing Agent Infrastructure

This directory contains the Terraform configuration for the Pricing Agent project. The infrastructure is deployed to AWS and includes components for Lambda functions, ECS services, Amazon Bedrock, and supporting resources.

## File Organization

The Terraform configuration is organized by component:

- `backend.tf` - S3 backend configuration for Terraform state
- `terraform-state.tf` - S3 bucket and DynamoDB table for state management
- `bedrock.tf` - Amazon Bedrock agent, knowledge base, and IAM resources
- `ecs.tf` - ECS cluster, service, task definition, and IAM resources
- `lambda.tf` - Lambda functions and IAM resources
- `vpc.tf` - VPC, subnets, security groups, and networking resources
- `dynamodb.tf` - DynamoDB tables for data storage
- `s3.tf` - S3 buckets for data storage
- `sqs.tf` - SQS queues for messaging
- `main.tf` - Provider configuration and shared resources
- `variables.tf` - Input variables
- `outputs.tf` - Output values

## Terraform State Management

This project uses an S3 backend for Terraform state management.

### Bootstrap Process

The first time you deploy, follow these steps:

1. Create an S3 bucket for Terraform state:
   ```bash
   # Create a unique bucket name
   BUCKET_NAME="pricing-agent-tf-state-$(whoami)"
   
   # Create the S3 bucket
   aws s3api create-bucket \
     --bucket $BUCKET_NAME \
     --region us-east-1
   
   # Enable versioning
   aws s3api put-bucket-versioning \
     --bucket $BUCKET_NAME \
     --versioning-configuration Status=Enabled
   
   # Block public access
   aws s3api put-public-access-block \
     --bucket $BUCKET_NAME \
     --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
   ```

2. Initialize Terraform with the S3 backend:
   ```bash
   terraform init \
     -backend-config="bucket=$BUCKET_NAME" \
     -backend-config="key=pricing-agent/terraform.tfstate" \
     -backend-config="region=us-east-1"
   ```

3. Deploy the infrastructure:
   ```bash
   terraform apply
   ```

This process is automated in the GitHub workflow but can be run manually as described above.

## Security Considerations

- All S3 buckets have versioning and encryption enabled
- Public access is blocked for all S3 buckets
- IAM roles follow least privilege principle
- All resources are tagged for better tracking
