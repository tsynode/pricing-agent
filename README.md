# Pricing Agent

A pricing compliance agent built with Strands Agents SDK and Streamlit, powered by Claude 3 Haiku.

## Overview

This application helps ensure products are priced correctly according to company policies and regulations. It uses the Strands Agents SDK to create an AI agent that can:

- Check if product prices comply with pricing policies
- Scan inventory for pricing issues
- Update product prices based on category-specific rules
- Apply time-based pricing for fresh produce items (morning and afternoon discounts)
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
- **LLM**: Claude 3 Haiku via Amazon Bedrock
- **Vector Database**: Amazon OpenSearch Serverless
- **Data Storage**: Amazon DynamoDB
- **Infrastructure**: AWS (ECS, ALB, S3) managed by Terraform
- **CI/CD**: GitHub Actions

## Demo Guide

Use the following sample questions and requests to demonstrate the pricing agent's capabilities:

### Pricing Policy Questions

1. "What are our pricing policies for electronics?"
2. "Explain the pricing rules for fresh produce."
3. "What time-based discounts do we apply to perishable items?"
4. "What are the margin requirements for premium electronics?"
5. "How do we handle pricing for items nearing expiration?"

### Price Compliance Checks

6. "Check if $4.50 is a compliant price for fresh bread (PROD017)."
7. "Is $899.99 a valid price for the 4K Smart TV (PROD005)?"
8. "Verify if $2.49 is within the allowed range for bananas (PROD020)."

### Inventory and Price Updates

9. "Scan inventory for pricing issues in the fresh produce category."
10. "Update the price of milk (PROD018) to $3.99."
11. "Find all products with prices below their minimum threshold."
12. "Update the price of the wireless earbuds (PROD008) to $89.99 and check compliance."

### Time-Based Pricing Scenarios

13. "How would the price of fresh strawberries change if it's currently 11:30 AM?"
14. "What would be the discounted price for fresh fish at 2:00 PM?"
15. "Explain how our time-based pricing strategy helps reduce waste for perishable items."

### Advanced Queries

16. "Compare pricing policies between electronics and fresh produce categories."
17. "What's our strategy for maintaining margins while implementing time-based discounts?"
18. "How do we ensure prices don't fall below wholesale costs when applying discounts?"
19. "What pricing adjustments should we make for the upcoming holiday season?"
20. "Analyze the effectiveness of our current fresh produce pricing strategy."

## License

[MIT License](LICENSE)
