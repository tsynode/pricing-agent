#!/bin/bash
# Script to manually clean up existing AWS resources for the staging environment
# This is a one-time script to remove resources that are outside Terraform state

set -e

# Environment to clean up
ENVIRONMENT="staging"
PROJECT="pricing-agent"
NAME_PREFIX="${PROJECT}-${ENVIRONMENT}"

echo "🧹 Cleaning up resources for ${NAME_PREFIX}..."

# Delete DynamoDB tables
echo "Deleting DynamoDB tables..."
aws dynamodb delete-table --table-name "${NAME_PREFIX}-pricing-rules" || echo "Table ${NAME_PREFIX}-pricing-rules doesn't exist or already deleted"
aws dynamodb delete-table --table-name "${NAME_PREFIX}-inventory" || echo "Table ${NAME_PREFIX}-inventory doesn't exist or already deleted"
aws dynamodb delete-table --table-name "${NAME_PREFIX}-sessions" || echo "Table ${NAME_PREFIX}-sessions doesn't exist or already deleted"

# Delete S3 buckets (need to empty them first)
echo "Emptying and deleting S3 buckets..."
aws s3 rm "s3://${NAME_PREFIX}-policies" --recursive || echo "Bucket ${NAME_PREFIX}-policies doesn't exist or already emptied"
aws s3 rb "s3://${NAME_PREFIX}-policies" --force || echo "Bucket ${NAME_PREFIX}-policies doesn't exist or already deleted"

aws s3 rm "s3://${NAME_PREFIX}-sessions" --recursive || echo "Bucket ${NAME_PREFIX}-sessions doesn't exist or already emptied"
aws s3 rb "s3://${NAME_PREFIX}-sessions" --force || echo "Bucket ${NAME_PREFIX}-sessions doesn't exist or already deleted"

# Delete IAM roles (need to detach policies first)
echo "Detaching policies and deleting IAM roles..."

# ECS execution role
for policy in $(aws iam list-attached-role-policies --role-name "${NAME_PREFIX}-ecs-execution-role" --query "AttachedPolicies[].PolicyArn" --output text 2>/dev/null || echo ""); do
  echo "Detaching policy $policy from ${NAME_PREFIX}-ecs-execution-role"
  aws iam detach-role-policy --role-name "${NAME_PREFIX}-ecs-execution-role" --policy-arn "$policy" || echo "Failed to detach policy"
done
aws iam delete-role --role-name "${NAME_PREFIX}-ecs-execution-role" || echo "Role ${NAME_PREFIX}-ecs-execution-role doesn't exist or already deleted"

# ECS task role
for policy in $(aws iam list-attached-role-policies --role-name "${NAME_PREFIX}-ecs-task-role" --query "AttachedPolicies[].PolicyArn" --output text 2>/dev/null || echo ""); do
  echo "Detaching policy $policy from ${NAME_PREFIX}-ecs-task-role"
  aws iam detach-role-policy --role-name "${NAME_PREFIX}-ecs-task-role" --policy-arn "$policy" || echo "Failed to detach policy"
done
aws iam delete-role --role-name "${NAME_PREFIX}-ecs-task-role" || echo "Role ${NAME_PREFIX}-ecs-task-role doesn't exist or already deleted"

# Check for ECS services and tasks
echo "Checking for ECS services..."
CLUSTER_NAME="${NAME_PREFIX}-cluster"
SERVICE_NAME="${NAME_PREFIX}-service"

# Update service to 0 desired count first
aws ecs update-service --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME" --desired-count 0 2>/dev/null || echo "ECS service ${SERVICE_NAME} doesn't exist or already deleted"

# Delete the service
aws ecs delete-service --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME" --force 2>/dev/null || echo "ECS service ${SERVICE_NAME} doesn't exist or already deleted"

# Delete the cluster
aws ecs delete-cluster --cluster "$CLUSTER_NAME" 2>/dev/null || echo "ECS cluster ${CLUSTER_NAME} doesn't exist or already deleted"

# Check for ALB and target groups
echo "Checking for ALB resources..."
ALB_ARN=$(aws elbv2 describe-load-balancers --names "${NAME_PREFIX}-alb" --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null || echo "")

if [[ "$ALB_ARN" != "None" && -n "$ALB_ARN" ]]; then
  # Get target groups
  TARGET_GROUPS=$(aws elbv2 describe-target-groups --load-balancer-arn "$ALB_ARN" --query "TargetGroups[].TargetGroupArn" --output text 2>/dev/null || echo "")
  
  # Delete listeners first
  LISTENERS=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --query "Listeners[].ListenerArn" --output text 2>/dev/null || echo "")
  for listener in $LISTENERS; do
    echo "Deleting listener $listener"
    aws elbv2 delete-listener --listener-arn "$listener" || echo "Failed to delete listener"
  done
  
  # Delete the ALB
  echo "Deleting ALB ${NAME_PREFIX}-alb"
  aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" || echo "Failed to delete ALB"
  
  # Delete target groups
  for tg in $TARGET_GROUPS; do
    echo "Deleting target group $tg"
    aws elbv2 delete-target-group --target-group-arn "$tg" || echo "Failed to delete target group"
  done
else
  echo "ALB ${NAME_PREFIX}-alb doesn't exist or already deleted"
fi

# Check for security groups
echo "Checking for security groups..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${NAME_PREFIX}-vpc" --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "")

if [[ "$VPC_ID" != "None" && -n "$VPC_ID" ]]; then
  # Delete ECS security group
  ECS_SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${NAME_PREFIX}-ecs-sg" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "")
  if [[ "$ECS_SG" != "None" && -n "$ECS_SG" ]]; then
    echo "Deleting ECS security group $ECS_SG"
    aws ec2 delete-security-group --group-id "$ECS_SG" || echo "Failed to delete ECS security group"
  fi
  
  # Delete ALB security group
  ALB_SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${NAME_PREFIX}-alb-sg" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "")
  if [[ "$ALB_SG" != "None" && -n "$ALB_SG" ]]; then
    echo "Deleting ALB security group $ALB_SG"
    aws ec2 delete-security-group --group-id "$ALB_SG" || echo "Failed to delete ALB security group"
  fi
  
  # Delete NAT Gateways
  NAT_GATEWAYS=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --query "NatGateways[?State!='deleted'].NatGatewayId" --output text 2>/dev/null || echo "")
  for nat in $NAT_GATEWAYS; do
    echo "Deleting NAT Gateway $nat"
    aws ec2 delete-nat-gateway --nat-gateway-id "$nat" || echo "Failed to delete NAT Gateway"
  done
  
  # Wait for NAT Gateways to be deleted before proceeding
  echo "Waiting for NAT Gateways to be deleted..."
  sleep 30
  
  # Delete route table associations and route tables
  ROUTE_TABLES=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" --output text 2>/dev/null || echo "")
  for rt in $ROUTE_TABLES; do
    # Get associations
    ASSOCS=$(aws ec2 describe-route-tables --route-table-ids "$rt" --query "RouteTables[0].Associations[?Main!=\`true\`].RouteTableAssociationId" --output text 2>/dev/null || echo "")
    for assoc in $ASSOCS; do
      echo "Deleting route table association $assoc"
      aws ec2 disassociate-route-table --association-id "$assoc" || echo "Failed to delete route table association"
    done
    
    echo "Deleting route table $rt"
    aws ec2 delete-route-table --route-table-id "$rt" || echo "Failed to delete route table"
  done
  
  # Delete Internet Gateway
  IGW=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[0].InternetGatewayId" --output text 2>/dev/null || echo "")
  if [[ "$IGW" != "None" && -n "$IGW" ]]; then
    echo "Detaching and deleting Internet Gateway $IGW"
    aws ec2 detach-internet-gateway --internet-gateway-id "$IGW" --vpc-id "$VPC_ID" || echo "Failed to detach Internet Gateway"
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW" || echo "Failed to delete Internet Gateway"
  fi
  
  # Delete subnets
  SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[].SubnetId" --output text 2>/dev/null || echo "")
  for subnet in $SUBNETS; do
    echo "Deleting subnet $subnet"
    aws ec2 delete-subnet --subnet-id "$subnet" || echo "Failed to delete subnet"
  done
  
  # Delete VPC
  echo "Deleting VPC $VPC_ID"
  aws ec2 delete-vpc --vpc-id "$VPC_ID" || echo "Failed to delete VPC"
else
  echo "VPC ${NAME_PREFIX}-vpc doesn't exist or already deleted"
fi

# Delete ECR repository
echo "Checking for ECR repository..."
ECR_REPO="${NAME_PREFIX}"
aws ecr delete-repository --repository-name "$ECR_REPO" --force 2>/dev/null || echo "ECR repository ${ECR_REPO} doesn't exist or already deleted"

# Delete SSM parameters
echo "Deleting SSM parameters..."
aws ssm delete-parameter --name "/${NAME_PREFIX}/pricing-table-name" 2>/dev/null || echo "SSM parameter /${NAME_PREFIX}/pricing-table-name doesn't exist or already deleted"
aws ssm delete-parameter --name "/${NAME_PREFIX}/inventory-table-name" 2>/dev/null || echo "SSM parameter /${NAME_PREFIX}/inventory-table-name doesn't exist or already deleted"
aws ssm delete-parameter --name "/${NAME_PREFIX}/sessions-table-name" 2>/dev/null || echo "SSM parameter /${NAME_PREFIX}/sessions-table-name doesn't exist or already deleted"
aws ssm delete-parameter --name "/${NAME_PREFIX}/kb-id" 2>/dev/null || echo "SSM parameter /${NAME_PREFIX}/kb-id doesn't exist or already deleted"

echo "✅ Cleanup completed for ${NAME_PREFIX}"
