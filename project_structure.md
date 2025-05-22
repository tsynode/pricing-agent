# Project Structure

```
pricing-agent/
├── .github/
│   └── workflows/
│       └── deploy.yml              # GitHub Actions workflow for deployment
├── infrastructure/
│   ├── main.tf                     # Main Terraform configuration
│   ├── variables.tf                # Terraform variables
│   ├── outputs.tf                  # Terraform outputs
│   ├── vpc.tf                      # VPC and networking resources
│   ├── ecs.tf                      # ECS Fargate resources
│   ├── lambda.tf                   # Lambda functions
│   ├── dynamodb.tf                 # DynamoDB tables
│   ├── sqs.tf                      # SQS queues
│   ├── bedrock.tf                  # Bedrock agent and knowledge base
│   ├── s3.tf                       # S3 bucket for pricing policies
│   └── iam.tf                      # IAM roles and policies
├── src/
│   ├── lambdas/
│   │   ├── inventory_scanner/
│   │   │   ├── requirements.txt
│   │   │   └── lambda_function.py
│   │   ├── batch_processor/
│   │   │   ├── requirements.txt
│   │   │   └── lambda_function.py
│   │   └── pricing_tools/
│   │       ├── requirements.txt
│   │       └── lambda_function.py
│   └── streamlit/
│       ├── Dockerfile
│       ├── requirements.txt
│       └── app.py
├── sample_data/
│   ├── dynamodb/
│   │   ├── product_financials.json
│   │   └── inventory.json
│   └── policies/
│       ├── general/
│       │   ├── margin-requirements.md
│       │   └── competitive-pricing.md
│       └── category-specific/
│           ├── electronics-pricing.md
│           └── apparel-seasonal.md
├── README.md
└── architecture_pricing_agent.drawio
```
