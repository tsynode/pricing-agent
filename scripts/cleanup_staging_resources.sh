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

# Delete IAM policies and roles
echo "Cleaning up IAM policies and roles..."

# Find and delete IAM policies
echo "Finding and deleting IAM policies..."
POLICY_ARNS=$(aws iam list-policies --scope Local --query "Policies[?starts_with(PolicyName, '${NAME_PREFIX}')].Arn" --output text)
if [[ -n "$POLICY_ARNS" ]]; then
  for policy_arn in $POLICY_ARNS; do
    echo "Found policy: $policy_arn"
    
    # Check if policy is attached to any roles
    ATTACHED_ENTITIES=$(aws iam list-entities-for-policy --policy-arn "$policy_arn" --output json)
    
    # Detach from roles if attached
    ROLE_NAMES=$(echo "$ATTACHED_ENTITIES" | jq -r '.PolicyRoles[].RoleName')
    if [[ -n "$ROLE_NAMES" ]]; then
      for role in $ROLE_NAMES; do
        echo "Detaching policy $policy_arn from role $role"
        aws iam detach-role-policy --role-name "$role" --policy-arn "$policy_arn" || echo "Failed to detach policy"
      done
    fi
    
    # Delete policy versions first (except default)
    VERSIONS=$(aws iam list-policy-versions --policy-arn "$policy_arn" --query "Versions[?!IsDefaultVersion].VersionId" --output text)
    if [[ -n "$VERSIONS" ]]; then
      for version in $VERSIONS; do
        echo "Deleting policy version $version"
        aws iam delete-policy-version --policy-arn "$policy_arn" --version-id "$version" || echo "Failed to delete policy version"
      done
    fi
    
    # Delete policy
    echo "Deleting policy $policy_arn"
    aws iam delete-policy --policy-arn "$policy_arn" || echo "Failed to delete policy"
  done
else
  echo "No IAM policies found with prefix ${NAME_PREFIX}"
fi

# ECS execution role
echo "Cleaning up ECS execution role..."
for policy in $(aws iam list-attached-role-policies --role-name "${NAME_PREFIX}-ecs-execution-role" --query "AttachedPolicies[].PolicyArn" --output text 2>/dev/null || echo ""); do
  echo "Detaching policy $policy from ${NAME_PREFIX}-ecs-execution-role"
  aws iam detach-role-policy --role-name "${NAME_PREFIX}-ecs-execution-role" --policy-arn "$policy" || echo "Failed to detach policy"
done
aws iam delete-role --role-name "${NAME_PREFIX}-ecs-execution-role" || echo "Role ${NAME_PREFIX}-ecs-execution-role doesn't exist or already deleted"

# ECS task role
echo "Cleaning up ECS task role..."
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

# First, find all target groups with the prefix, regardless of ALB association
echo "Finding all target groups with prefix ${NAME_PREFIX}..."
ALL_TARGET_GROUPS=$(aws elbv2 describe-target-groups --query "TargetGroups[?starts_with(TargetGroupName, '${NAME_PREFIX}')].TargetGroupArn" --output text 2>/dev/null || echo "")

# Find all ALBs with the prefix
echo "Finding all ALBs with prefix ${NAME_PREFIX}..."
ALL_ALBS=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?starts_with(LoadBalancerName, '${NAME_PREFIX}')].LoadBalancerArn" --output text 2>/dev/null || echo "")

# Process each ALB
if [[ -n "$ALL_ALBS" ]]; then
  for alb_arn in $ALL_ALBS; do
    echo "Processing ALB: $alb_arn"
    
    # Get target groups associated with this ALB
    ALB_TARGET_GROUPS=$(aws elbv2 describe-target-groups --load-balancer-arn "$alb_arn" --query "TargetGroups[].TargetGroupArn" --output text 2>/dev/null || echo "")
    
    # Delete listeners first
    LISTENERS=$(aws elbv2 describe-listeners --load-balancer-arn "$alb_arn" --query "Listeners[].ListenerArn" --output text 2>/dev/null || echo "")
    if [[ -n "$LISTENERS" ]]; then
      for listener in $LISTENERS; do
        echo "Deleting listener $listener"
        aws elbv2 delete-listener --listener-arn "$listener" || echo "Failed to delete listener"
      done
    else
      echo "No listeners found for ALB $alb_arn"
    fi
    
    # Modify ALB to disable deletion protection
    echo "Disabling deletion protection for ALB $alb_arn..."
    aws elbv2 modify-load-balancer-attributes --load-balancer-arn "$alb_arn" --attributes Key=deletion_protection.enabled,Value=false || echo "Failed to disable deletion protection"
    
    # Delete the ALB
    echo "Deleting ALB $alb_arn"
    aws elbv2 delete-load-balancer --load-balancer-arn "$alb_arn" || echo "Failed to delete ALB"
  done
else
  echo "No ALBs found with prefix ${NAME_PREFIX}"
fi

# Now delete all target groups, including those that might not be associated with an ALB
if [[ -n "$ALL_TARGET_GROUPS" ]]; then
  echo "Deleting all target groups with prefix ${NAME_PREFIX}..."
  for tg in $ALL_TARGET_GROUPS; do
    # Wait a bit to ensure ALB deletion has completed
    sleep 5
    echo "Deleting target group $tg"
    aws elbv2 delete-target-group --target-group-arn "$tg" || echo "Failed to delete target group"
  done
else
  echo "No target groups found with prefix ${NAME_PREFIX}"
fi

# Check for security groups and VPC resources
echo "Checking for VPC resources..."

# Find all VPCs that might be related to our application
echo "Finding all potentially related VPCs..."
POTENTIAL_VPCS=$(aws ec2 describe-vpcs --query "Vpcs[].VpcId" --output text)

# First, find the explicitly tagged VPC
TAGGED_VPC=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${NAME_PREFIX}-vpc" --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "")
if [[ "$TAGGED_VPC" != "None" && -n "$TAGGED_VPC" ]]; then
  echo "Found tagged VPC: $TAGGED_VPC"
  VPC_IDS="$TAGGED_VPC"
else
  echo "No explicitly tagged VPC found for ${NAME_PREFIX}-vpc"
  VPC_IDS=""
fi

# Find security groups related to our application across all VPCs
echo "Finding security groups related to ${NAME_PREFIX} across all VPCs..."
for vpc in $POTENTIAL_VPCS; do
  # Look for ECS security groups
  ECS_SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc" "Name=group-name,Values=*${NAME_PREFIX}*ecs*" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "")
  if [[ "$ECS_SG" != "None" && -n "$ECS_SG" ]]; then
    echo "Found ECS security group $ECS_SG in VPC $vpc"
    if [[ ! " $VPC_IDS " =~ " $vpc " ]]; then
      VPC_IDS="$VPC_IDS $vpc"
    fi
  fi
  
  # Look for ALB security groups
  ALB_SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc" "Name=group-name,Values=*${NAME_PREFIX}*alb*" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "")
  if [[ "$ALB_SG" != "None" && -n "$ALB_SG" ]]; then
    echo "Found ALB security group $ALB_SG in VPC $vpc"
    if [[ ! " $VPC_IDS " =~ " $vpc " ]]; then
      VPC_IDS="$VPC_IDS $vpc"
    fi
  fi
done

# Clean up each identified VPC
for VPC_ID in $VPC_IDS; do
  echo "\n🧹 Cleaning up resources in VPC: $VPC_ID"
  
  # Find and delete all security groups in this VPC related to our application
  echo "Finding all security groups in VPC $VPC_ID related to ${NAME_PREFIX}..."
  SG_IDS=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=*${NAME_PREFIX}*" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text 2>/dev/null || echo "")
  
  # Delete all non-default security groups
  for sg in $SG_IDS; do
    echo "Attempting to delete security group $sg"
    # First remove all ingress rules
    aws ec2 revoke-security-group-ingress --group-id "$sg" --protocol all --source-group "$sg" 2>/dev/null || echo "No self-referencing rules to revoke"
    aws ec2 revoke-security-group-ingress --group-id "$sg" --ip-permissions "$(aws ec2 describe-security-groups --group-ids "$sg" --query 'SecurityGroups[0].IpPermissions' --output json)" 2>/dev/null || echo "No ingress rules to revoke"
    
    # Then remove all egress rules
    aws ec2 revoke-security-group-egress --group-id "$sg" --ip-permissions "$(aws ec2 describe-security-groups --group-ids "$sg" --query 'SecurityGroups[0].IpPermissionsEgress' --output json)" 2>/dev/null || echo "No egress rules to revoke"
    
    # Now try to delete the security group
    aws ec2 delete-security-group --group-id "$sg" || echo "Failed to delete security group $sg"
  done
  
  # Delete NAT Gateways
  echo "Finding and deleting NAT Gateways in VPC $VPC_ID..."
  NAT_GATEWAYS=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --query "NatGateways[?State!='deleted'].NatGatewayId" --output text 2>/dev/null || echo "")
  for nat in $NAT_GATEWAYS; do
    echo "Deleting NAT Gateway $nat"
    aws ec2 delete-nat-gateway --nat-gateway-id "$nat" || echo "Failed to delete NAT Gateway"
  done
  
  # Wait for NAT Gateways to be deleted before proceeding
  if [[ -n "$NAT_GATEWAYS" ]]; then
    echo "Waiting for NAT Gateways to be deleted..."
    sleep 30
  fi
  
  # Delete route table associations and route tables
  echo "Finding and deleting route tables in VPC $VPC_ID..."
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
  echo "Finding and deleting Internet Gateway for VPC $VPC_ID..."
  IGW=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[0].InternetGatewayId" --output text 2>/dev/null || echo "")
  if [[ "$IGW" != "None" && -n "$IGW" ]]; then
    echo "Detaching and deleting Internet Gateway $IGW"
    aws ec2 detach-internet-gateway --internet-gateway-id "$IGW" --vpc-id "$VPC_ID" || echo "Failed to detach Internet Gateway"
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW" || echo "Failed to delete Internet Gateway"
  fi
  
  # Delete subnets
  echo "Finding and deleting subnets in VPC $VPC_ID..."
  SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[].SubnetId" --output text 2>/dev/null || echo "")
  for subnet in $SUBNETS; do
    echo "Deleting subnet $subnet"
    aws ec2 delete-subnet --subnet-id "$subnet" || echo "Failed to delete subnet"
  done
  
  # Delete VPC
  echo "Deleting VPC $VPC_ID"
  aws ec2 delete-vpc --vpc-id "$VPC_ID" || echo "Failed to delete VPC"
done

if [[ -z "$VPC_IDS" ]]; then
  echo "No VPCs found related to ${NAME_PREFIX}"
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
