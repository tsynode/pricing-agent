# AI-Powered Pricing Compliance System

## Overview
This repository contains an intelligent pricing compliance system that automatically monitors and adjusts product prices based on dynamic pricing policies. The system uses Amazon Bedrock's agentic AI to make autonomous pricing decisions while handling millions of inventory items through scalable batch processing.

## Key Capabilities

- **Scheduled Compliance Checks**: Every 10 minutes automated scans of entire inventory
- **Manual Interactive Queries**: Category managers can ask questions like "Do we have non-compliant items?"
- **Intelligent Decision Making**: AI agent interprets pricing policies and makes contextual decisions
- **Scalable Processing**: Handles millions of items through SQS batching
- **Policy Management**: Dynamic policies stored in Knowledge Base (no code changes needed)
- **Competitive Pricing**: Market-aware pricing decisions based on configurable policies

## Architecture

The system is built on AWS services with a serverless architecture:

- **VPC with Public/Private Subnets**: Secure networking across 2 AZs
- **EventBridge Rule**: Triggers inventory scanning every 10 minutes
- **SQS Queue with DLQ**: Manages batch processing of inventory items
- **Lambda Functions**:
  - Inventory Scanner: Scans inventory and creates batches
  - Batch Processor: Bridges SQS to Bedrock Agent
  - Pricing Tools: Provides pricing operations for the agent
- **DynamoDB Tables**: Store product financials and inventory data
- **Amazon Bedrock**: AI agent and knowledge base for pricing decisions
- **ECS Fargate**: Hosts the Streamlit UI for category managers
- **S3 Bucket**: Stores pricing policy documents

## Getting Started

### Prerequisites
- AWS Account with appropriate permissions
- Terraform 1.0.0+
- Docker
- Python 3.11+
- AWS CLI configured
- Amazon Bedrock access

### Deployment

#### Option 1: Automated Deployment (GitHub Actions)

1. Fork this repository
2. Configure AWS credentials in GitHub repository secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
3. Push to the main branch to trigger deployment

#### Option 2: Manual Deployment

1. Clone the repository
   ```bash
   git clone https://github.com/tsynode/pricing-agent.git
   cd pricing-agent
   ```

2. Deploy infrastructure with Terraform
   ```bash
   cd infrastructure
   terraform init
   terraform apply
   ```

3. Package and deploy Lambda functions
   ```bash
   # Create deployment packages
   cd ../src/lambdas
   # Follow packaging instructions in deployment guide
   ```

4. Build and push Streamlit Docker image
   ```bash
   cd ../src/streamlit
   docker build -t pricing-agent-streamlit .
   # Tag and push to ECR (see deployment guide)
   ```

## Usage

### Streamlit UI

Access the Streamlit UI through the Application Load Balancer URL provided in the Terraform outputs:

```
http://<alb_dns_name>
```

The UI provides:
- Natural language query interface to the Bedrock agent
- Compliance dashboard with metrics and recent updates
- Pricing policy viewer

### Scheduled Operations

The system automatically:
- Scans inventory every 10 minutes
- Processes items in batches through SQS
- Updates non-compliant prices based on policies
- Maintains audit trail of all price changes

## Project Structure

```
pricing-agent/
├── .github/workflows/      # GitHub Actions workflow
├── infrastructure/         # Terraform IaC
├── src/
│   ├── lambdas/            # Lambda function code
│   └── streamlit/          # Streamlit UI application
└── sample_data/            # Sample data for testing
```

## Customization

### Pricing Policies

Customize pricing policies by adding markdown documents to the S3 bucket. The knowledge base will automatically index these documents for the agent to use in decision-making.

### Agent Behavior

Modify the agent's behavior by updating the instruction prompt in `infrastructure/bedrock.tf`.

## License
TBD

## Acknowledgements
This project leverages Amazon Bedrock for AI capabilities and follows AWS best practices for serverless architecture.