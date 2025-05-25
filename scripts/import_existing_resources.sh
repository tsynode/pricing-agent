#!/bin/bash
# One-time import script for existing AWS resources into Terraform state
# This script should be run once before the first Terraform apply
# to properly import existing resources and prevent conflicts

set -e

# Check if environment variable is set
if [ -z "$ENVIRONMENT" ]; then
  echo "Error: ENVIRONMENT variable is not set"
  echo "Usage: ENVIRONMENT=staging AWS_REGION=us-east-1 ./import_existing_resources.sh"
  exit 1
fi

if [ -z "$AWS_REGION" ]; then
  echo "Error: AWS_REGION variable is not set"
  echo "Usage: ENVIRONMENT=staging AWS_REGION=us-east-1 ./import_existing_resources.sh"
  exit 1
fi

echo "🔍 Starting import of existing resources for environment: $ENVIRONMENT in region: $AWS_REGION"
cd "$(dirname "$0")/../infrastructure"

# Get VPC ID
echo "Checking for existing VPC..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=pricing-agent-${ENVIRONMENT}-vpc" --query "Vpcs[0].VpcId" --output text --region $AWS_REGION 2>/dev/null || echo "NOT_FOUND")

if [[ "$VPC_ID" == "NOT_FOUND" || "$VPC_ID" == "None" ]]; then
  echo "⚠️ No existing VPC found. Skipping network resource imports."
else
  echo "✅ Found existing VPC: $VPC_ID"
  
  # Import VPC
  echo "Importing VPC..."
  terraform state rm aws_vpc.main 2>/dev/null || true
  terraform import aws_vpc.main $VPC_ID
  
  # Get public subnets
  echo "Checking for existing public subnets..."
  PUBLIC_SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=pricing-agent-${ENVIRONMENT}-public-subnet-*" --query "Subnets[*].SubnetId" --output text --region $AWS_REGION)
  
  # Import public subnets
  if [[ -n "$PUBLIC_SUBNETS" && "$PUBLIC_SUBNETS" != "None" ]]; then
    echo "Found public subnets: $PUBLIC_SUBNETS"
    INDEX=0
    for SUBNET_ID in $PUBLIC_SUBNETS; do
      echo "Importing public subnet $SUBNET_ID at index $INDEX..."
      terraform state rm "aws_subnet.public[$INDEX]" 2>/dev/null || true
      terraform import "aws_subnet.public[$INDEX]" $SUBNET_ID
      INDEX=$((INDEX+1))
    done
  fi
  
  # Get private subnets
  echo "Checking for existing private subnets..."
  PRIVATE_SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=pricing-agent-${ENVIRONMENT}-private-subnet-*" --query "Subnets[*].SubnetId" --output text --region $AWS_REGION)
  
  # Import private subnets
  if [[ -n "$PRIVATE_SUBNETS" && "$PRIVATE_SUBNETS" != "None" ]]; then
    echo "Found private subnets: $PRIVATE_SUBNETS"
    INDEX=0
    for SUBNET_ID in $PRIVATE_SUBNETS; do
      echo "Importing private subnet $SUBNET_ID at index $INDEX..."
      terraform state rm "aws_subnet.private[$INDEX]" 2>/dev/null || true
      terraform import "aws_subnet.private[$INDEX]" $SUBNET_ID
      INDEX=$((INDEX+1))
    done
  fi
  
  # Import Internet Gateway
  echo "Checking for existing Internet Gateway..."
  IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[0].InternetGatewayId" --output text --region $AWS_REGION 2>/dev/null || echo "NOT_FOUND")
  if [[ "$IGW_ID" != "NOT_FOUND" && "$IGW_ID" != "None" ]]; then
    echo "Importing Internet Gateway $IGW_ID..."
    terraform state rm aws_internet_gateway.main 2>/dev/null || true
    terraform import aws_internet_gateway.main $IGW_ID
  fi
  
  # Import route tables
  echo "Checking for existing route tables..."
  
  # Public route table
  PUBLIC_RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=pricing-agent-${ENVIRONMENT}-public-rt" --query "RouteTables[0].RouteTableId" --output text --region $AWS_REGION 2>/dev/null || echo "NOT_FOUND")
  if [[ "$PUBLIC_RT" != "NOT_FOUND" && "$PUBLIC_RT" != "None" ]]; then
    echo "Importing public route table $PUBLIC_RT..."
    terraform state rm aws_route_table.public 2>/dev/null || true
    terraform import aws_route_table.public $PUBLIC_RT
    
    # Import public route table associations
    if [[ -n "$PUBLIC_SUBNETS" && "$PUBLIC_SUBNETS" != "None" ]]; then
      echo "Importing public route table associations..."
      INDEX=0
      for SUBNET_ID in $PUBLIC_SUBNETS; do
        # For route table associations, we need to use the format 'subnet_id/route_table_id'
        if [[ -n "$SUBNET_ID" && "$SUBNET_ID" != "None" && -n "$PUBLIC_RT" && "$PUBLIC_RT" != "None" ]]; then
          echo "Importing public route table association for subnet $SUBNET_ID with route table $PUBLIC_RT"
          # First check if the association exists in AWS
          ASSOC_ID=$(aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$SUBNET_ID" --query "RouteTables[0].Associations[?SubnetId=='$SUBNET_ID'].RouteTableAssociationId" --output text --region $AWS_REGION 2>/dev/null || echo "NOT_FOUND")
          if [[ "$ASSOC_ID" != "NOT_FOUND" && "$ASSOC_ID" != "None" && -n "$ASSOC_ID" ]]; then
            # Verify the route table ID matches what we expect
            RT_ID=$(aws ec2 describe-route-tables --filters "Name=association.route-table-association-id,Values=$ASSOC_ID" --query "RouteTables[0].RouteTableId" --output text --region $AWS_REGION 2>/dev/null || echo "NOT_FOUND")
            if [[ "$RT_ID" == "$PUBLIC_RT" ]]; then
              echo "Found association ID: $ASSOC_ID between subnet $SUBNET_ID and route table $PUBLIC_RT"
              terraform state rm "aws_route_table_association.public[$INDEX]" 2>/dev/null || true
              terraform import "aws_route_table_association.public[$INDEX]" "$SUBNET_ID/$PUBLIC_RT"
            else
              echo "⚠️ Subnet $SUBNET_ID is associated with route table $RT_ID, not $PUBLIC_RT. Skipping import."
            fi
          else
            echo "⚠️ No association found for subnet $SUBNET_ID, skipping import"
          fi
        fi
        INDEX=$((INDEX+1))
      done
    fi
  fi
  
  # Private route tables
  echo "Checking for existing private route tables..."
  INDEX=0
  for AZ in $(aws ec2 describe-availability-zones --query "AvailabilityZones[*].ZoneName" --output text --region $AWS_REGION | tr '\t' '\n' | head -n $(echo "$PRIVATE_SUBNETS" | wc -w)); do
    PRIVATE_RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=pricing-agent-${ENVIRONMENT}-private-rt-$((INDEX+1))" --query "RouteTables[0].RouteTableId" --output text --region $AWS_REGION 2>/dev/null || echo "NOT_FOUND")
    if [[ "$PRIVATE_RT" != "NOT_FOUND" && "$PRIVATE_RT" != "None" ]]; then
      echo "Importing private route table $PRIVATE_RT at index $INDEX..."
      terraform state rm "aws_route_table.private[$INDEX]" 2>/dev/null || true
      terraform import "aws_route_table.private[$INDEX]" $PRIVATE_RT
      
      # Get the private subnet ID for this AZ
      SUBNET_ID=$(echo "$PRIVATE_SUBNETS" | tr '\t' '\n' | sed -n "$((INDEX+1))p")
      if [[ -n "$SUBNET_ID" ]]; then
        # For route table associations, we need to use the format 'subnet_id/route_table_id'
        if [[ -n "$SUBNET_ID" && "$SUBNET_ID" != "None" && -n "$PRIVATE_RT" && "$PRIVATE_RT" != "None" ]]; then
          echo "Importing private route table association for subnet $SUBNET_ID with route table $PRIVATE_RT"
          # First check if the association exists in AWS
          ASSOC_ID=$(aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$SUBNET_ID" --query "RouteTables[0].Associations[?SubnetId=='$SUBNET_ID'].RouteTableAssociationId" --output text --region $AWS_REGION 2>/dev/null || echo "NOT_FOUND")
          if [[ "$ASSOC_ID" != "NOT_FOUND" && "$ASSOC_ID" != "None" && -n "$ASSOC_ID" ]]; then
            # Verify the route table ID matches what we expect
            RT_ID=$(aws ec2 describe-route-tables --filters "Name=association.route-table-association-id,Values=$ASSOC_ID" --query "RouteTables[0].RouteTableId" --output text --region $AWS_REGION 2>/dev/null || echo "NOT_FOUND")
            if [[ "$RT_ID" == "$PRIVATE_RT" ]]; then
              echo "Found association ID: $ASSOC_ID between subnet $SUBNET_ID and route table $PRIVATE_RT"
              terraform state rm "aws_route_table_association.private[$INDEX]" 2>/dev/null || true
              terraform import "aws_route_table_association.private[$INDEX]" "$SUBNET_ID/$PRIVATE_RT"
            else
              echo "⚠️ Subnet $SUBNET_ID is associated with route table $RT_ID, not $PRIVATE_RT. Skipping import."
            fi
          else
            echo "⚠️ No association found for subnet $SUBNET_ID, skipping import"
          fi
        fi
      fi
    fi
    INDEX=$((INDEX+1))
  done
  
  # Import security groups
  echo "Checking for existing security groups..."
  
  # ALB security group
  ALB_SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=pricing-agent-${ENVIRONMENT}-alb-sg" --query "SecurityGroups[0].GroupId" --output text --region $AWS_REGION 2>/dev/null || echo "NOT_FOUND")
  if [[ "$ALB_SG" != "NOT_FOUND" && "$ALB_SG" != "None" ]]; then
    echo "Importing ALB security group $ALB_SG..."
    terraform state rm aws_security_group.alb 2>/dev/null || true
    terraform import aws_security_group.alb $ALB_SG
  fi
  
  # ECS security group
  ECS_SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=pricing-agent-${ENVIRONMENT}-ecs-sg" --query "SecurityGroups[0].GroupId" --output text --region $AWS_REGION 2>/dev/null || echo "NOT_FOUND")
  if [[ "$ECS_SG" != "NOT_FOUND" && "$ECS_SG" != "None" ]]; then
    echo "Importing ECS security group $ECS_SG..."
    terraform state rm aws_security_group.ecs 2>/dev/null || true
    terraform import aws_security_group.ecs $ECS_SG
  fi
fi

# Import DynamoDB tables
echo "Checking for existing DynamoDB tables..."

# Pricing table
PRICING_TABLE_EXISTS=$(aws dynamodb describe-table --table-name pricing-agent-${ENVIRONMENT}-pricing-rules --region $AWS_REGION 2>/dev/null || echo "NOT_FOUND")
if [[ "$PRICING_TABLE_EXISTS" != "NOT_FOUND" ]]; then
  echo "Importing existing pricing table..."
  terraform state rm aws_dynamodb_table.pricing 2>/dev/null || true
  terraform import aws_dynamodb_table.pricing pricing-agent-${ENVIRONMENT}-pricing-rules
fi

# Inventory table
INVENTORY_TABLE_EXISTS=$(aws dynamodb describe-table --table-name pricing-agent-${ENVIRONMENT}-inventory --region $AWS_REGION 2>/dev/null || echo "NOT_FOUND")
if [[ "$INVENTORY_TABLE_EXISTS" != "NOT_FOUND" ]]; then
  echo "Importing existing inventory table..."
  terraform state rm aws_dynamodb_table.inventory 2>/dev/null || true
  terraform import aws_dynamodb_table.inventory pricing-agent-${ENVIRONMENT}-inventory
fi

# Sessions table
SESSIONS_TABLE_EXISTS=$(aws dynamodb describe-table --table-name pricing-agent-${ENVIRONMENT}-sessions --region $AWS_REGION 2>/dev/null || echo "NOT_FOUND")
if [[ "$SESSIONS_TABLE_EXISTS" != "NOT_FOUND" ]]; then
  echo "Importing existing sessions table..."
  terraform state rm aws_dynamodb_table.sessions 2>/dev/null || true
  terraform import aws_dynamodb_table.sessions pricing-agent-${ENVIRONMENT}-sessions
fi

# Import S3 buckets
echo "Checking for existing S3 buckets..."

# Policy bucket
POLICY_BUCKET_EXISTS=$(aws s3api head-bucket --bucket pricing-agent-${ENVIRONMENT}-policies --region $AWS_REGION 2>/dev/null || echo "NOT_FOUND")
if [[ "$POLICY_BUCKET_EXISTS" != "NOT_FOUND" ]]; then
  echo "Importing existing policy bucket..."
  terraform state rm aws_s3_bucket.policy 2>/dev/null || true
  terraform import aws_s3_bucket.policy pricing-agent-${ENVIRONMENT}-policies
fi

# Session bucket
SESSION_BUCKET_EXISTS=$(aws s3api head-bucket --bucket pricing-agent-${ENVIRONMENT}-sessions --region $AWS_REGION 2>/dev/null || echo "NOT_FOUND")
if [[ "$SESSION_BUCKET_EXISTS" != "NOT_FOUND" ]]; then
  echo "Importing existing session bucket..."
  terraform state rm aws_s3_bucket.session 2>/dev/null || true
  terraform import aws_s3_bucket.session pricing-agent-${ENVIRONMENT}-sessions
fi

# Import IAM roles
echo "Checking for existing IAM roles..."

# ECS execution role
ECS_EXEC_ROLE=$(aws iam get-role --role-name pricing-agent-${ENVIRONMENT}-ecs-execution-role 2>/dev/null | jq -r '.Role.RoleName' || echo "NOT_FOUND")
if [[ "$ECS_EXEC_ROLE" != "NOT_FOUND" ]]; then
  echo "Importing existing ECS execution role..."
  terraform state rm aws_iam_role.ecs_execution 2>/dev/null || true
  terraform import aws_iam_role.ecs_execution pricing-agent-${ENVIRONMENT}-ecs-execution-role
fi

# ECS task role
ECS_TASK_ROLE=$(aws iam get-role --role-name pricing-agent-${ENVIRONMENT}-ecs-task-role 2>/dev/null | jq -r '.Role.RoleName' || echo "NOT_FOUND")
if [[ "$ECS_TASK_ROLE" != "NOT_FOUND" ]]; then
  echo "Importing existing ECS task role..."
  terraform state rm aws_iam_role.ecs_task 2>/dev/null || true
  terraform import aws_iam_role.ecs_task pricing-agent-${ENVIRONMENT}-ecs-task-role
fi

echo "✅ Import script completed successfully"
