#!/bin/bash
# Script to set up AWS Bedrock resources after Terraform deployment
# This script uses the AWS CLI to create and configure Bedrock resources

set -e

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Get Terraform outputs
echo "Getting Terraform outputs..."
cd ../infrastructure
AGENT_NAME=$(terraform output -raw bedrock_agent_name)
AGENT_ALIAS_NAME=$(terraform output -raw bedrock_agent_alias_name)
KB_NAME=$(terraform output -raw bedrock_knowledge_base_name)
MODEL_ID=$(terraform output -raw bedrock_model_id)
EMBEDDING_MODEL_ID=$(terraform output -raw bedrock_embedding_model_id)
S3_BUCKET=$(terraform output -raw s3_bucket_name)
REGION=$(terraform output -raw aws_region)
LAMBDA_INVENTORY_ARN=$(terraform output -raw lambda_inventory_scanner_arn)
LAMBDA_PRICING_ARN=$(terraform output -raw lambda_pricing_tools_arn)
IAM_ROLE_ARN=$(terraform output -raw bedrock_service_role_arn)

# Load API schemas from Terraform outputs
INVENTORY_TOOLS_SCHEMA=$(terraform output -raw inventory_tools_schema)
PRICING_TOOLS_SCHEMA=$(terraform output -raw pricing_tools_schema)
AGENT_INSTRUCTION=$(terraform output -raw bedrock_agent_instruction)

echo "Creating Bedrock Knowledge Base..."
KB_RESPONSE=$(aws bedrock create-knowledge-base \
    --region $REGION \
    --name $KB_NAME \
    --description "Knowledge base for pricing policies" \
    --role-arn $IAM_ROLE_ARN \
    --knowledge-base-configuration "type=VECTOR,vectorKnowledgeBaseConfiguration={embeddingModelArn=arn:aws:bedrock:$REGION::foundation-model/$EMBEDDING_MODEL_ID}" \
    --storage-configuration "type=OPENSEARCH_SERVERLESS,opensearchServerlessConfiguration={collectionName=$KB_NAME-collection,vectorFieldName=embedding,textFieldName=text,fieldMapping=[{fieldName=document_id,fieldType=STRING},{fieldName=policy_type,fieldType=STRING},{fieldName=category,fieldType=STRING}]}")

KB_ID=$(echo $KB_RESPONSE | jq -r '.knowledgeBaseId')
echo "Knowledge Base created with ID: $KB_ID"

echo "Creating Knowledge Base Data Source..."
aws bedrock create-data-source \
    --region $REGION \
    --knowledge-base-id $KB_ID \
    --name "$KB_NAME-data-source" \
    --description "S3 data source for pricing policies" \
    --data-source-configuration "type=S3,s3Configuration={bucketName=$S3_BUCKET,inclusionPrefixes=[pricing-policies/]}" \
    --vector-ingestion-configuration "chunkingConfiguration={chunkingStrategy=FIXED_SIZE,fixedSizeChunkingConfiguration={maxTokens=300,overlap=20}}" \
    --role-arn $IAM_ROLE_ARN

echo "Creating Bedrock Agent..."
AGENT_RESPONSE=$(aws bedrock create-agent \
    --region $REGION \
    --agent-name $AGENT_NAME \
    --agent-resource-role-arn $IAM_ROLE_ARN \
    --foundation-model "arn:aws:bedrock:$REGION::foundation-model/$MODEL_ID" \
    --idle-session-ttl-in-seconds 1800 \
    --instruction "$AGENT_INSTRUCTION")

AGENT_ID=$(echo $AGENT_RESPONSE | jq -r '.agentId')
echo "Agent created with ID: $AGENT_ID"

echo "Associating Knowledge Base with Agent..."
aws bedrock create-agent-knowledge-base \
    --region $REGION \
    --agent-id $AGENT_ID \
    --knowledge-base-id $KB_ID \
    --description "Pricing policies knowledge base" \
    --knowledge-base-state ENABLED

echo "Creating Inventory Tools Action Group..."
aws bedrock create-agent-action-group \
    --region $REGION \
    --agent-id $AGENT_ID \
    --action-group-name "InventoryTools" \
    --action-group-executor "lambda={lambdaArn=$LAMBDA_INVENTORY_ARN}" \
    --description "Tools for scanning inventory" \
    --api-schema "$INVENTORY_TOOLS_SCHEMA" \
    --action-group-state ENABLED

echo "Creating Pricing Tools Action Group..."
aws bedrock create-agent-action-group \
    --region $REGION \
    --agent-id $AGENT_ID \
    --action-group-name "PricingTools" \
    --action-group-executor "lambda={lambdaArn=$LAMBDA_PRICING_ARN}" \
    --description "Tools for managing product prices" \
    --api-schema "$PRICING_TOOLS_SCHEMA" \
    --action-group-state ENABLED

echo "Creating Agent Alias..."
aws bedrock create-agent-alias \
    --region $REGION \
    --agent-id $AGENT_ID \
    --agent-alias-name $AGENT_ALIAS_NAME \
    --description "Alias for pricing compliance agent" \
    --routing-configuration "agentVersion=DRAFT"

echo "Preparing Agent..."
aws bedrock prepare-agent \
    --region $REGION \
    --agent-id $AGENT_ID

echo "Bedrock resources setup complete!"
echo "Agent ID: $AGENT_ID"
echo "Knowledge Base ID: $KB_ID"
