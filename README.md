# Pricing Agent

A pricing compliance agent built with Strands Agents SDK and Streamlit, powered by Claude 3.7 Sonnet.

## Overview

This application helps ensure products are priced correctly according to company policies and regulations. It uses the Strands Agents SDK to create an AI agent that can:

- Check if product prices comply with pricing policies
- Scan inventory for pricing issues
- Update product prices
- Explain pricing policies to users using the Bedrock Knowledge Base

## Architecture

## Architecture

![Current Architecture](docs/images/minimal_architecture.png)

The architecture follows a "stupid simple" approach that prioritizes simplicity and maintainability:

- **Streamlit UI with Strands Agent**: A single container running both the UI and agent
- **Direct Tool Integration**: Tools are implemented as Python functions with the `@tool` decorator
- **Knowledge Base**: Bedrock Knowledge Base with OpenSearch for policy retrieval
- **Data Storage**: DynamoDB tables for pricing rules and inventory data

This architecture delivers core functionality while minimizing infrastructure complexity for easier troubleshooting.

## Deployment

The deployment process is fully automated using GitHub Actions and Terraform:

- **GitHub Repository**: Source code and policy documents
- **GitHub Actions**: Automated workflows for deployment, destruction, and KB syncing
- **Terraform**: Infrastructure as Code for all AWS resources

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
├── docs/                       # Documentation
│   └── images/                 # Architecture diagrams
│
├── infrastructure/             # Terraform infrastructure
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── vpc.tf
│   ├── ecs.tf
│   ├── alb.tf
│   ├── s3.tf
│   ├── dynamodb.tf
│   ├── iam.tf
│   └── bedrock_kb.tf
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
- GitHub account to fork/clone this repository

### Deployment Steps

1. **Set up GitHub Secrets**:
   - `AWS_ACCESS_KEY_ID`: AWS access key with appropriate permissions
   - `AWS_SECRET_ACCESS_KEY`: Corresponding AWS secret key

2. **Trigger Deployment**:
   - Push to the main branch, or
   - Manually trigger the workflow from GitHub Actions tab

3. **Access the Application**:
   - The application URL will be available in the Terraform outputs
   - This can be found in the GitHub Actions logs or AWS Console

## Knowledge Base Management

Pricing policies are stored in the `policies/` directory. To update policies:

1. Edit the policy files in the appropriate subdirectory
2. Commit and push changes to the repository
3. Run the Knowledge Base sync workflow from the GitHub Actions tab

## Technology Stack

- **Frontend**: Streamlit
- **Agent Framework**: Strands Agents SDK
- **LLM**: Claude 3.7 Sonnet via Amazon Bedrock
- **Vector Database**: Amazon OpenSearch Serverless
- **Data Storage**: Amazon DynamoDB
- **Infrastructure**: AWS (ECS, ALB, S3) managed by Terraform
- **CI/CD**: GitHub Actions

## License

[MIT License](LICENSE)
