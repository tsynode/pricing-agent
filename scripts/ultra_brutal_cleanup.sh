#!/bin/bash
set -e

# ULTRA BRUTAL CLEANUP SCRIPT
# This script will DESTROY ALL resources related to the pricing agent
# No mercy. No survivors.

echo "🔥🔥🔥 INITIATING ULTRA BRUTAL CLEANUP 🔥🔥🔥"
echo "💀 THE SLAYER HAS ENTERED THE FACILITY 💀"

# Set environment variables
ENVIRONMENTS=("dev" "staging" "prod")
AWS_REGION="us-east-1"

for ENV in "${ENVIRONMENTS[@]}"; do
  NAME_PREFIX="pricing-agent-${ENV}"
  echo "🔪🔪🔪 PURGING ALL RESOURCES FOR ${NAME_PREFIX} 🔪🔪🔪"
  
  # 1. DESTROY ALL ECS RESOURCES
  echo "🔥 OBLITERATING ECS RESOURCES..."
  CLUSTER_NAME="${NAME_PREFIX}-cluster"
  SERVICE_NAME="${NAME_PREFIX}-service"
  
  # Scale down service to 0 tasks first
  aws ecs update-service --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME" --desired-count 0 2>/dev/null || echo "Service already dead"
  
  # Force delete the service
  aws ecs delete-service --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME" --force 2>/dev/null || echo "Service already annihilated"
  
  # Delete task definitions
  TASK_DEFS=$(aws ecs list-task-definitions --family-prefix "$NAME_PREFIX" --status ACTIVE --query 'taskDefinitionArns[]' --output text)
  if [ -n "$TASK_DEFS" ]; then
    for td in $TASK_DEFS; do
      echo "Deregistering task definition $td"
      aws ecs deregister-task-definition --task-definition "$td" > /dev/null
    done
  fi
  
  # Delete the cluster
  aws ecs delete-cluster --cluster "$CLUSTER_NAME" 2>/dev/null || echo "Cluster already destroyed"
  
  # 2. DESTROY ALL LOAD BALANCER RESOURCES
  echo "🔥 ANNIHILATING LOAD BALANCERS..."
  
  # Find target groups
  TARGET_GROUPS=$(aws elbv2 describe-target-groups --query "TargetGroups[?starts_with(TargetGroupName, '${NAME_PREFIX}')].TargetGroupArn" --output text 2>/dev/null || echo "")
  
  # Find load balancers
  ALBS=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?starts_with(LoadBalancerName, '${NAME_PREFIX}')].LoadBalancerArn" --output text 2>/dev/null || echo "")
  
  # Delete load balancers and their listeners
  for alb in $ALBS; do
    # Delete listeners first
    LISTENERS=$(aws elbv2 describe-listeners --load-balancer-arn "$alb" --query "Listeners[].ListenerArn" --output text 2>/dev/null || echo "")
    for listener in $LISTENERS; do
      echo "Destroying listener $listener"
      aws elbv2 delete-listener --listener-arn "$listener" 2>/dev/null || echo "Listener already dead"
    done
    
    # Disable deletion protection
    aws elbv2 modify-load-balancer-attributes --load-balancer-arn "$alb" --attributes Key=deletion_protection.enabled,Value=false 2>/dev/null || echo "Protection already disabled"
    
    # Delete the load balancer
    echo "Destroying load balancer $alb"
    aws elbv2 delete-load-balancer --load-balancer-arn "$alb" 2>/dev/null || echo "Load balancer already obliterated"
  done
  
  # Delete target groups
  for tg in $TARGET_GROUPS; do
    echo "Destroying target group $tg"
    aws elbv2 delete-target-group --target-group-arn "$tg" 2>/dev/null || echo "Target group already annihilated"
  done
  
  # 3. DESTROY ALL DYNAMODB TABLES
  echo "🔥 DECIMATING DYNAMODB TABLES..."
  TABLES=("${NAME_PREFIX}-sessions" "${NAME_PREFIX}-inventory" "${NAME_PREFIX}-pricing-rules")
  
  for table in "${TABLES[@]}"; do
    echo "Destroying table $table"
    aws dynamodb delete-table --table-name "$table" 2>/dev/null || echo "Table $table already obliterated"
  done
  
  # 4. DESTROY ALL S3 BUCKETS
  echo "🔥 INCINERATING S3 BUCKETS..."
  BUCKETS=("${NAME_PREFIX}-policies")
  
  for bucket in "${BUCKETS[@]}"; do
    echo "Checking if bucket $bucket exists..."
    if aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
      echo "Purging all objects from bucket $bucket..."
      
      # Simpler approach - first remove all objects
      aws s3 rm "s3://$bucket" --recursive
      
      # Force delete the bucket with all its contents
      echo "Destroying bucket $bucket with force option"
      aws s3 rb "s3://$bucket" --force 2>/dev/null || echo "Failed to destroy bucket $bucket"
    else
      echo "Bucket $bucket doesn't exist or you don't have permission to access it"
    fi
  done
  
  # 5. DESTROY ALL IAM ROLES AND POLICIES
  echo "🔥 EXTERMINATING IAM ROLES AND POLICIES..."
  
  # Roles to destroy
  ROLES=(
    "${NAME_PREFIX}-ecs-execution-role"
    "${NAME_PREFIX}-ecs-task-role"
    "${NAME_PREFIX}-kb-role"
    "${NAME_PREFIX}-bedrock-management-role"
  )
  
  # Detach and delete policies from roles
  for role in "${ROLES[@]}"; do
    echo "Processing role: $role"
    
    # Get attached policies
    ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "$role" --query "AttachedPolicies[].PolicyArn" --output text 2>/dev/null || echo "")
    
    # Detach policies
    for policy in $ATTACHED_POLICIES; do
      echo "Detaching policy: $policy from role: $role"
      aws iam detach-role-policy --role-name "$role" --policy-arn "$policy" 2>/dev/null || echo "Failed to detach policy"
    done
    
    # Delete role
    echo "Destroying role: $role"
    aws iam delete-role --role-name "$role" 2>/dev/null || echo "Role already annihilated"
  done
  
  # Find and destroy customer managed policies
  POLICIES=$(aws iam list-policies --scope Local --query "Policies[?starts_with(PolicyName, '${NAME_PREFIX}')].{Name:PolicyName,Arn:Arn}" --output text 2>/dev/null || echo "")
  
  while read -r arn name; do
    if [ -n "$arn" ]; then
      echo "Processing policy: $name ($arn)"
      
      # Get policy versions
      VERSIONS=$(aws iam list-policy-versions --policy-arn "$arn" --query "Versions[?!IsDefaultVersion].VersionId" --output text 2>/dev/null || echo "")
      
      # Delete non-default versions
      for version in $VERSIONS; do
        echo "Destroying policy version: $version"
        aws iam delete-policy-version --policy-arn "$arn" --version-id "$version" 2>/dev/null || echo "Failed to destroy policy version"
      done
      
      # Delete policy
      echo "Destroying policy: $name"
      aws iam delete-policy --policy-arn "$arn" 2>/dev/null || echo "Failed to destroy policy"
    fi
  done <<< "$POLICIES"
  
  # 6. DESTROY ALL VPC RESOURCES
  echo "🔥 DEMOLISHING VPC RESOURCES..."
  
  # Find VPCs related to our application
  VPC_IDS=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${NAME_PREFIX}-vpc" --query "Vpcs[].VpcId" --output text 2>/dev/null || echo "")
  
  # If no VPCs found by tag, try to find by security group name
  if [ -z "$VPC_IDS" ]; then
    # Look for security groups with our prefix to find VPCs
    for sg in $(aws ec2 describe-security-groups --query "SecurityGroups[?contains(GroupName, '${NAME_PREFIX}')].{Id:GroupId,VpcId:VpcId}" --output text 2>/dev/null || echo ""); do
      if [[ "$sg" == vpc-* ]]; then
        VPC_IDS="$VPC_IDS $sg"
      fi
    done
    
    # Remove duplicates
    VPC_IDS=$(echo "$VPC_IDS" | tr ' ' '\n' | sort -u | tr '\n' ' ')
  fi
  
  for vpc in $VPC_IDS; do
    echo "Processing VPC: $vpc"
    
    # Delete load balancers in this VPC (if any remaining)
    for lb in $(aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='$vpc'].LoadBalancerArn" --output text 2>/dev/null || echo ""); do
      echo "Destroying load balancer in VPC $vpc: $lb"
      aws elbv2 delete-load-balancer --load-balancer-arn "$lb" 2>/dev/null || echo "Load balancer already annihilated"
    done
    
    # Delete NAT Gateways
    for nat in $(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$vpc" --query "NatGateways[].NatGatewayId" --output text 2>/dev/null || echo ""); do
      echo "Destroying NAT Gateway: $nat"
      aws ec2 delete-nat-gateway --nat-gateway-id "$nat" 2>/dev/null || echo "NAT Gateway already annihilated"
    done
    
    # Wait for NAT Gateways to be deleted
    sleep 10
    
    # Release Elastic IPs
    for eip in $(aws ec2 describe-addresses --query "Addresses[].AllocationId" --output text 2>/dev/null || echo ""); do
      echo "Releasing Elastic IP: $eip"
      aws ec2 release-address --allocation-id "$eip" 2>/dev/null || echo "Elastic IP already released"
    done
    
    # Delete security groups
    for sg in $(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text 2>/dev/null || echo ""); do
      echo "Destroying security group: $sg"
      aws ec2 delete-security-group --group-id "$sg" 2>/dev/null || echo "Security group already annihilated"
    done
    
    # Delete subnets
    for subnet in $(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc" --query "Subnets[].SubnetId" --output text 2>/dev/null || echo ""); do
      echo "Destroying subnet: $subnet"
      aws ec2 delete-subnet --subnet-id "$subnet" 2>/dev/null || echo "Subnet already annihilated"
    done
    
    # Delete route tables
    for rt in $(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc" --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" --output text 2>/dev/null || echo ""); do
      echo "Destroying route table: $rt"
      aws ec2 delete-route-table --route-table-id "$rt" 2>/dev/null || echo "Route table already annihilated"
    done
    
    # Detach and delete internet gateways
    for igw in $(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc" --query "InternetGateways[].InternetGatewayId" --output text 2>/dev/null || echo ""); do
      echo "Detaching internet gateway: $igw"
      aws ec2 detach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$vpc" 2>/dev/null || echo "Internet gateway already detached"
      
      echo "Destroying internet gateway: $igw"
      aws ec2 delete-internet-gateway --internet-gateway-id "$igw" 2>/dev/null || echo "Internet gateway already annihilated"
    done
    
    # Delete the VPC
    echo "Destroying VPC: $vpc"
    aws ec2 delete-vpc --vpc-id "$vpc" 2>/dev/null || echo "VPC already annihilated"
  done
  
  # 7. DESTROY ALL CLOUDWATCH LOGS
  echo "🔥 ERADICATING CLOUDWATCH LOGS..."
  LOG_GROUPS=("/ecs/${NAME_PREFIX}" "/aws/lambda/${NAME_PREFIX}")
  
  for lg in "${LOG_GROUPS[@]}"; do
    echo "Destroying log group: $lg"
    aws logs delete-log-group --log-group-name "$lg" 2>/dev/null || echo "Log group already annihilated"
  done
  
  # 8. DESTROY ALL ECR REPOSITORIES
  echo "🔥 VAPORIZING ECR REPOSITORIES..."
  REPO_NAME="${NAME_PREFIX}"
  
  # Force delete all images in the repository
  IMAGES=$(aws ecr list-images --repository-name "$REPO_NAME" --query 'imageIds[*]' --output json 2>/dev/null || echo "[]")
  if [ "$IMAGES" != "[]" ]; then
    echo "Purging all images from repository $REPO_NAME"
    aws ecr batch-delete-image --repository-name "$REPO_NAME" --image-ids "$(echo $IMAGES)" 2>/dev/null || echo "Failed to purge images"
  fi
  
  # Delete the repository
  echo "Destroying repository: $REPO_NAME"
  aws ecr delete-repository --repository-name "$REPO_NAME" --force 2>/dev/null || echo "Repository already annihilated"
  
  # 9. DESTROY ALL SSM PARAMETERS
  echo "🔥 PURGING SSM PARAMETERS..."
  PARAMS=("/pricing-agent-${ENV}/knowledge-base-id" "/pricing-agent-${ENV}/sessions-table-name")
  
  for param in "${PARAMS[@]}"; do
    echo "Destroying parameter: $param"
    aws ssm delete-parameter --name "$param" 2>/dev/null || echo "Parameter already annihilated"
  done
  
  # 10. DESTROY ALL BEDROCK RESOURCES
  echo "🔥 OBLITERATING BEDROCK RESOURCES..."
  
  # List and delete knowledge bases
  KB_IDS=$(aws bedrock list-knowledge-bases --query "knowledgeBases[?contains(name, '${NAME_PREFIX}')].knowledgeBaseId" --output text 2>/dev/null || echo "")
  
  for kb in $KB_IDS; do
    echo "Destroying knowledge base: $kb"
    aws bedrock delete-knowledge-base --knowledge-base-id "$kb" 2>/dev/null || echo "Knowledge base already annihilated"
  done
  
  echo "🔥🔥🔥 ${NAME_PREFIX} RESOURCES HAVE BEEN BRUTALLY DESTROYED 🔥🔥🔥"
  echo ""
done

echo "💀💀💀 ULTRA BRUTAL CLEANUP COMPLETE 💀💀💀"
echo "THE SLAYER'S WORK IS DONE... FOR NOW"
