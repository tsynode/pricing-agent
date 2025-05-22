# Pricing Agent

A pricing compliance agent built with Strands Agents SDK and Streamlit.

## Overview

This application helps ensure products are priced correctly according to company policies and regulations. It uses the Strands Agents SDK to create an AI agent powered by Claude that can:

- Check if product prices comply with pricing policies
- Scan inventory for pricing issues
- Update product prices
- Explain pricing policies to users using the knowledge base

## Architecture

- **Strands Agents SDK**: Powers the AI agent with Claude 3 Sonnet
- **Streamlit**: Provides the user interface
- **AWS Services**:
  - ECS Fargate: Hosts the containerized application
  - DynamoDB: Stores pricing rules and inventory data
  - S3: Stores pricing policy documents
  - Bedrock Knowledge Base: Stores and retrieves pricing policies
  - OpenSearch Serverless: Powers the vector search for the knowledge base

## Repository Structure

```
pricing-agent/
│
├── app/                        # Application code
│   ├── __init__.py
│   ├── agent.py                # Strands agent definition
│   ├── tools/                  # Custom pricing tools
│   │   ├── __init__.py
│   │   ├── pricing.py
│   │   └── inventory.py
│   ├── app.py                  # Streamlit UI
│   └── requirements.txt        # Python dependencies
│
├── infrastructure/             # Terraform infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── vpc.tf
│   ├── ecs.tf
│   ├── alb.tf
│   ├── s3.tf
│   ├── dynamodb.tf
│   ├── iam.tf
│   ├── bedrock.tf
│   └── backend.tf
│
├── policies/                   # Policy documents (KB source)
│   ├── general/
│   │   └── general_pricing_policy.txt
│   ├── electronics/
│   │   └── electronics_pricing_policy.txt
│   └── clothing/
│       └── clothing_pricing_policy.txt
│
├── scripts/
│   └── sync_kb.py              # Script to sync KB with policies
│
└── .github/
    └── workflows/
        ├── deploy.yml          # Main deployment workflow
        ├── destroy.yml         # Cleanup workflow
        └── sync_kb.yml         # KB sync workflow
```

## Getting Started

### Prerequisites

- AWS Account with appropriate permissions
- Terraform installed
- Python 3.12 or higher
- Docker (for local development)

### Local Development

1. Install dependencies:
   ```
   cd app
   pip install -r requirements.txt
   ```

2. Run the Streamlit app locally:
   ```
   cd app
   streamlit run app.py
   ```

### Deployment

1. Configure AWS credentials:
   ```
   aws configure
   ```

2. Initialize Terraform:
   ```
   cd infrastructure
   terraform init
   ```

3. Deploy the infrastructure:
   ```
   terraform apply
   ```

4. The application will be available at the ALB URL provided in the Terraform outputs.

## Knowledge Base Management

Pricing policies are stored in the `policies/` directory. To update policies:

1. Edit the policy files in the appropriate subdirectory
2. Commit and push changes to the repository
3. The GitHub Actions workflow will automatically sync the changes to the knowledge base

## License

[MIT License](LICENSE)
