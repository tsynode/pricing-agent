#!/bin/bash
# BRUTAL CLEANUP SCRIPT - REMOVES ALL PRICING AGENT RESOURCES
# Warning: This script forcefully deletes all resources related to pricing-agent
# Use with caution!

set -e

echo "🔥 STARTING BRUTAL CLEANUP OF ALL PRICING AGENT RESOURCES 🔥"
echo "This will forcefully delete ALL resources related to pricing-agent in both dev and staging environments."
echo "Press Ctrl+C within 5 seconds to abort..."
sleep 5

# AWS Region
export AWS_REGION=$(aws configure get region)
echo "Using AWS Region: $AWS_REGION"

# Resource prefixes to target
PREFIXES=("pricing-agent-dev" "pricing-agent-staging")

echo "=== CLEANING UP ECS RESOURCES ==="
for PREFIX in "${PREFIXES[@]}"; do
  echo "Cleaning up ECS resources for $PREFIX..."
  
  # Get cluster ARN
  CLUSTER_ARN=$(aws ecs list-clusters --query "clusterArns[?contains(@,'$PREFIX')]" --output text)
  
  if [ ! -z "$CLUSTER_ARN" ]; then
    echo "Found cluster: $CLUSTER_ARN"
    
    # Get services in cluster
    SERVICES=$(aws ecs list-services --cluster $CLUSTER_ARN --query "serviceArns[]" --output text)
    
    # Update services to 0 desired count and force delete
    for SERVICE in $SERVICES; do
      echo "Scaling down service: $SERVICE"
      aws ecs update-service --cluster $CLUSTER_ARN --service $SERVICE --desired-count 0 --force-new-deployment || true
      
      echo "Waiting for tasks to stop..."
      sleep 10
      
      echo "Deleting service: $SERVICE"
      aws ecs delete-service --cluster $CLUSTER_ARN --service $SERVICE --force || true
    done
    
    # Delete the cluster
    echo "Deleting cluster: $CLUSTER_ARN"
    aws ecs delete-cluster --cluster $CLUSTER_ARN || true
  else
    echo "No ECS cluster found for $PREFIX"
  fi
done

echo "=== CLEANING UP ALB RESOURCES ==="
# Find and delete target groups
for PREFIX in "${PREFIXES[@]}"; do
  echo "Cleaning up ALB resources for $PREFIX..."
  
  # Find load balancers
  ALBS=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName,'$PREFIX')].[LoadBalancerArn]" --output text)
  
  for ALB in $ALBS; do
    if [ ! -z "$ALB" ]; then
      echo "Found ALB: $ALB"
      
      # Delete listeners first
      LISTENERS=$(aws elbv2 describe-listeners --load-balancer-arn $ALB --query "Listeners[*].ListenerArn" --output text)
      for LISTENER in $LISTENERS; do
        echo "Deleting listener: $LISTENER"
        aws elbv2 delete-listener --listener-arn $LISTENER || true
      done
      
      # Disable deletion protection
      echo "Disabling deletion protection"
      aws elbv2 modify-load-balancer-attributes --load-balancer-arn $ALB --attributes Key=deletion_protection.enabled,Value=false || true
      
      # Delete the ALB
      echo "Deleting ALB: $ALB"
      aws elbv2 delete-load-balancer --load-balancer-arn $ALB || true
    fi
  done
  
  # Find and delete target groups
  TARGET_GROUPS=$(aws elbv2 describe-target-groups --query "TargetGroups[?contains(TargetGroupName,'$PREFIX')].[TargetGroupArn]" --output text)
  
  for TG in $TARGET_GROUPS; do
    if [ ! -z "$TG" ]; then
      echo "Deleting target group: $TG"
      aws elbv2 delete-target-group --target-group-arn $TG || true
    fi
  done
done

echo "=== CLEANING UP DYNAMODB TABLES ==="
for PREFIX in "${PREFIXES[@]}"; do
  echo "Cleaning up DynamoDB tables for $PREFIX..."
  
  # List tables with our prefix
  TABLES=$(aws dynamodb list-tables --query "TableNames[?contains(@,'$PREFIX')]" --output text)
  
  for TABLE in $TABLES; do
    echo "Deleting table: $TABLE"
    aws dynamodb delete-table --table-name $TABLE || true
  done
done

echo "=== CLEANING UP S3 BUCKETS ==="
for PREFIX in "${PREFIXES[@]}"; do
  echo "Cleaning up S3 buckets for $PREFIX..."
  
  # List buckets with our prefix
  BUCKETS=$(aws s3api list-buckets --query "Buckets[?contains(Name,'$PREFIX')].Name" --output text)
  
  for BUCKET in $BUCKETS; do
    echo "Emptying bucket: $BUCKET"
    aws s3 rm s3://$BUCKET --recursive || true
    
    echo "Deleting bucket: $BUCKET"
    aws s3api delete-bucket --bucket $BUCKET || true
  done
done

echo "=== CLEANING UP ECR REPOSITORIES ==="
# Find ECR repositories
REPOS=$(aws ecr describe-repositories --query "repositories[?contains(repositoryName,'pricing-agent')].repositoryName" --output text)

for REPO in $REPOS; do
  echo "Cleaning up ECR repository: $REPO"
  
  # Delete all images in the repository
  IMAGES=$(aws ecr list-images --repository-name $REPO --query 'imageIds[*]' --output json)
  
  if [ "$IMAGES" != "[]" ] && [ ! -z "$IMAGES" ]; then
    echo "Deleting all images in repository: $REPO"
    aws ecr batch-delete-image --repository-name $REPO --image-ids "$(echo $IMAGES)" || true
  fi
  
  # Force delete the repository
  echo "Deleting repository: $REPO"
  aws ecr delete-repository --repository-name $REPO --force || true
done

echo "=== CLEANING UP IAM RESOURCES ==="
for PREFIX in "${PREFIXES[@]}"; do
  echo "Cleaning up IAM resources for $PREFIX..."
  
  # Find and detach policies from roles
  ROLES=$(aws iam list-roles --query "Roles[?contains(RoleName,'$PREFIX')].RoleName" --output text)
  
  for ROLE in $ROLES; do
    echo "Processing role: $ROLE"
    
    # Get attached policies
    POLICIES=$(aws iam list-attached-role-policies --role-name $ROLE --query "AttachedPolicies[*].PolicyArn" --output text)
    
    # Detach policies
    for POLICY in $POLICIES; do
      echo "Detaching policy: $POLICY from role: $ROLE"
      aws iam detach-role-policy --role-name $ROLE --policy-arn $POLICY || true
    done
    
    # Delete role
    echo "Deleting role: $ROLE"
    aws iam delete-role --role-name $ROLE || true
  done
  
  # Find and delete policies
  POLICIES=$(aws iam list-policies --scope Local --query "Policies[?contains(PolicyName,'$PREFIX')].Arn" --output text)
  
  for POLICY in $POLICIES; do
    echo "Deleting policy: $POLICY"
    
    # Delete all versions except the default
    VERSIONS=$(aws iam list-policy-versions --policy-arn $POLICY --query "Versions[?IsDefaultVersion==\`false\`].VersionId" --output text)
    
    for VERSION in $VERSIONS; do
      echo "Deleting policy version: $VERSION"
      aws iam delete-policy-version --policy-arn $POLICY --version-id $VERSION || true
    done
    
    # Delete the policy
    aws iam delete-policy --policy-arn $POLICY || true
  done
done

echo "=== CLEANING UP VPC RESOURCES ==="
for PREFIX in "${PREFIXES[@]}"; do
  echo "Cleaning up VPC resources for $PREFIX..."
  
  # Find VPCs related to our application
  VPC_IDS=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${PREFIX}*" --query "Vpcs[*].VpcId" --output text)
  
  if [ -z "$VPC_IDS" ]; then
    echo "No VPCs found with prefix $PREFIX, looking for security groups..."
    
    # Look for security groups with our prefix to find VPCs
    SG_VPC_IDS=$(aws ec2 describe-security-groups --query "SecurityGroups[?contains(GroupName,'$PREFIX')].VpcId" --output text | sort | uniq)
    
    if [ ! -z "$SG_VPC_IDS" ]; then
      VPC_IDS=$SG_VPC_IDS
    fi
  fi
  
  for VPC in $VPC_IDS; do
    echo "Processing VPC: $VPC"
    
    # Delete load balancers in this VPC (if any remaining)
    LBS=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='$VPC'].LoadBalancerArn" --output text)
    for LB in $LBS; do
      echo "Deleting load balancer: $LB"
      aws elbv2 delete-load-balancer --load-balancer-arn $LB || true
    done
    
    # Delete NAT Gateways
    NAT_GATEWAYS=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" --query "NatGateways[*].NatGatewayId" --output text)
    for NAT in $NAT_GATEWAYS; do
      echo "Deleting NAT Gateway: $NAT"
      aws ec2 delete-nat-gateway --nat-gateway-id $NAT || true
    done
    
    # Wait for NAT Gateways to be deleted
    sleep 10
    
    # Delete Elastic IPs
    EIPS=$(aws ec2 describe-addresses --query "Addresses[?contains(Tags[?Key=='Name'].Value, '$PREFIX')].AllocationId" --output text)
    if [ -z "$EIPS" ]; then
      EIPS=$(aws ec2 describe-addresses --filter "Name=domain,Values=vpc" --query "Addresses[*].AllocationId" --output text)
    fi
    
    for EIP in $EIPS; do
      echo "Releasing Elastic IP: $EIP"
      aws ec2 release-address --allocation-id $EIP || true
    done
    
    # Delete security groups
    SG_IDS=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)
    for SG in $SG_IDS; do
      echo "Deleting security group: $SG"
      aws ec2 delete-security-group --group-id $SG || true
    done
    
    # Delete subnets
    SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" --query "Subnets[*].SubnetId" --output text)
    for SUBNET in $SUBNETS; do
      echo "Deleting subnet: $SUBNET"
      aws ec2 delete-subnet --subnet-id $SUBNET || true
    done
    
    # Delete route tables
    RT_IDS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC" --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" --output text)
    for RT in $RT_IDS; do
      echo "Deleting route table: $RT"
      aws ec2 delete-route-table --route-table-id $RT || true
    done
    
    # Delete internet gateways
    IGW_IDS=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC" --query "InternetGateways[*].InternetGatewayId" --output text)
    for IGW in $IGW_IDS; do
      echo "Detaching internet gateway: $IGW"
      aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC || true
      
      echo "Deleting internet gateway: $IGW"
      aws ec2 delete-internet-gateway --internet-gateway-id $IGW || true
    done
    
    # Delete VPC
    echo "Deleting VPC: $VPC"
    aws ec2 delete-vpc --vpc-id $VPC || true
  done
done

echo "=== CLEANING UP SSM PARAMETERS ==="
for PREFIX in "${PREFIXES[@]}"; do
  echo "Cleaning up SSM parameters for $PREFIX..."
  
  # List parameters with our prefix
  PARAMETERS=$(aws ssm describe-parameters --parameter-filters "Key=Name,Option=Contains,Values=/$PREFIX/" --query "Parameters[*].Name" --output text)
  
  for PARAM in $PARAMETERS; do
    echo "Deleting parameter: $PARAM"
    aws ssm delete-parameter --name $PARAM || true
  done
done

echo "=== CLEANING UP CLOUDWATCH LOG GROUPS ==="
for PREFIX in "${PREFIXES[@]}"; do
  echo "Cleaning up CloudWatch log groups for $PREFIX..."
  
  # List log groups with our prefix
  LOG_GROUPS=$(aws logs describe-log-groups --log-group-name-prefix "/ecs/$PREFIX" --query "logGroups[*].logGroupName" --output text)
  
  for LOG_GROUP in $LOG_GROUPS; do
    echo "Deleting log group: $LOG_GROUP"
    aws logs delete-log-group --log-group-name $LOG_GROUP || true
  done
done

echo "=== CLEANING UP BEDROCK KNOWLEDGE BASES ==="
# List knowledge bases
KB_IDS=$(aws bedrock list-knowledge-bases --query "knowledgeBases[?contains(name,'pricing-agent')].knowledgeBaseId" --output text)

for KB_ID in $KB_IDS; do
  echo "Deleting knowledge base: $KB_ID"
  aws bedrock delete-knowledge-base --knowledge-base-id $KB_ID || true
done

echo "🧹 BRUTAL CLEANUP COMPLETE! 🧹"
echo "All pricing agent resources should now be deleted."
