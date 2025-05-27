#!/bin/bash
# Enhanced VPC cleanup script to handle dependencies properly
# This script focuses on removing all dependencies before attempting to delete VPC resources

set -e

# Environment to clean up
ENVIRONMENT="staging"
PROJECT="pricing-agent"
NAME_PREFIX="${PROJECT}-${ENVIRONMENT}"
REGION="${AWS_REGION:-us-east-1}"

echo "🧹 Enhanced VPC cleanup for ${NAME_PREFIX}..."

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
  echo -e "\n🧹 Enhanced cleanup for VPC: $VPC_ID"
  
  # Step 1: Find and terminate any EC2 instances
  echo "Finding and terminating EC2 instances in VPC $VPC_ID..."
  INSTANCES=$(aws ec2 describe-instances --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=pending,running,stopping,stopped" --query "Reservations[].Instances[].InstanceId" --output text)
  if [[ -n "$INSTANCES" ]]; then
    echo "Terminating instances: $INSTANCES"
    aws ec2 terminate-instances --instance-ids $INSTANCES || echo "Failed to terminate instances"
    echo "Waiting for instances to terminate..."
    aws ec2 wait instance-terminated --instance-ids $INSTANCES
  else
    echo "No EC2 instances found in VPC $VPC_ID"
  fi
  
  # Step 2: Find and stop any ECS tasks
  echo "Finding and stopping ECS tasks related to ${NAME_PREFIX}..."
  CLUSTERS=$(aws ecs list-clusters --query "clusterArns[]" --output text)
  for cluster in $CLUSTERS; do
    CLUSTER_NAME=$(echo $cluster | awk -F'/' '{print $2}')
    if [[ "$CLUSTER_NAME" == *"$NAME_PREFIX"* ]]; then
      echo "Found ECS cluster: $CLUSTER_NAME"
      SERVICES=$(aws ecs list-services --cluster $CLUSTER_NAME --query "serviceArns[]" --output text 2>/dev/null || echo "")
      if [[ -n "$SERVICES" ]]; then
        for service in $SERVICES; do
          SERVICE_NAME=$(echo $service | awk -F'/' '{print $3}')
          echo "Updating service $SERVICE_NAME to 0 desired count"
          aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --desired-count 0 || echo "Failed to update service"
          echo "Waiting for tasks to stop..."
          sleep 10
        done
      fi
      
      # Find and stop any remaining tasks
      TASKS=$(aws ecs list-tasks --cluster $CLUSTER_NAME --query "taskArns[]" --output text 2>/dev/null || echo "")
      if [[ -n "$TASKS" ]]; then
        echo "Stopping remaining tasks in cluster $CLUSTER_NAME"
        aws ecs stop-task --cluster $CLUSTER_NAME --task $TASKS || echo "Failed to stop tasks"
        echo "Waiting for tasks to stop..."
        sleep 10
      fi
    fi
  done
  
  # Step 3: Find and delete any ELBs
  echo "Finding and deleting load balancers in VPC $VPC_ID..."
  LBS=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text)
  if [[ -n "$LBS" ]]; then
    for lb in $LBS; do
      echo "Deleting load balancer $lb"
      # Delete listeners first
      LISTENERS=$(aws elbv2 describe-listeners --load-balancer-arn $lb --query "Listeners[].ListenerArn" --output text 2>/dev/null || echo "")
      for listener in $LISTENERS; do
        echo "Deleting listener $listener"
        aws elbv2 delete-listener --listener-arn $listener || echo "Failed to delete listener"
      done
      
      # Modify attributes to disable deletion protection
      echo "Disabling deletion protection for $lb"
      aws elbv2 modify-load-balancer-attributes --load-balancer-arn $lb --attributes Key=deletion_protection.enabled,Value=false || echo "Failed to disable deletion protection"
      
      # Delete the load balancer
      aws elbv2 delete-load-balancer --load-balancer-arn $lb || echo "Failed to delete load balancer"
    done
    
    # Wait for load balancers to be deleted
    echo "Waiting for load balancers to be deleted..."
    sleep 30
  else
    echo "No load balancers found in VPC $VPC_ID"
  fi
  
  # Step 4: Find and delete target groups
  echo "Finding and deleting target groups in VPC $VPC_ID..."
  TGS=$(aws elbv2 describe-target-groups --query "TargetGroups[?VpcId=='$VPC_ID'].TargetGroupArn" --output text)
  if [[ -n "$TGS" ]]; then
    for tg in $TGS; do
      echo "Deleting target group $tg"
      aws elbv2 delete-target-group --target-group-arn $tg || echo "Failed to delete target group"
    done
  else
    echo "No target groups found in VPC $VPC_ID"
  fi
  
  # Step 5: Find and release Elastic IPs
  echo "Finding and releasing Elastic IPs in VPC $VPC_ID..."
  # Get all EIPs associated with the VPC
  ALLOCATION_IDS=$(aws ec2 describe-addresses --filters "Name=domain,Values=vpc" --query "Addresses[].AllocationId" --output text)
  if [[ -n "$ALLOCATION_IDS" ]]; then
    for alloc_id in $ALLOCATION_IDS; do
      # Check if this EIP is associated with an ENI in our VPC
      ASSOCIATION_ID=$(aws ec2 describe-addresses --allocation-ids $alloc_id --query "Addresses[0].AssociationId" --output text)
      if [[ "$ASSOCIATION_ID" != "None" && -n "$ASSOCIATION_ID" ]]; then
        # Get the network interface ID
        ENI_ID=$(aws ec2 describe-addresses --allocation-ids $alloc_id --query "Addresses[0].NetworkInterfaceId" --output text)
        # Check if this ENI is in our VPC
        ENI_VPC=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI_ID --query "NetworkInterfaces[0].VpcId" --output text 2>/dev/null || echo "")
        if [[ "$ENI_VPC" == "$VPC_ID" ]]; then
          echo "Disassociating Elastic IP $alloc_id from ENI $ENI_ID"
          aws ec2 disassociate-address --association-id $ASSOCIATION_ID || echo "Failed to disassociate Elastic IP"
          echo "Releasing Elastic IP $alloc_id"
          aws ec2 release-address --allocation-id $alloc_id || echo "Failed to release Elastic IP"
        fi
      fi
    done
  else
    echo "No Elastic IPs found"
  fi
  
  # Step 6: Find and delete network interfaces
  echo "Finding and deleting network interfaces in VPC $VPC_ID..."
  ENIS=$(aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC_ID" --query "NetworkInterfaces[].NetworkInterfaceId" --output text)
  if [[ -n "$ENIS" ]]; then
    for eni in $ENIS; do
      echo "Detaching network interface $eni if attached"
      ATTACHMENT=$(aws ec2 describe-network-interfaces --network-interface-ids $eni --query "NetworkInterfaces[0].Attachment.AttachmentId" --output text 2>/dev/null || echo "")
      if [[ "$ATTACHMENT" != "None" && -n "$ATTACHMENT" ]]; then
        echo "Detaching attachment $ATTACHMENT"
        aws ec2 detach-network-interface --attachment-id $ATTACHMENT --force || echo "Failed to detach network interface"
        # Wait for detachment to complete
        sleep 5
      fi
      
      echo "Deleting network interface $eni"
      aws ec2 delete-network-interface --network-interface-id $eni || echo "Failed to delete network interface"
    done
  else
    echo "No network interfaces found in VPC $VPC_ID"
  fi
  
  # Step 7: Find and delete all security groups (except default)
  echo "Finding and deleting security groups in VPC $VPC_ID..."
  SG_IDS=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)
  if [[ -n "$SG_IDS" ]]; then
    for sg in $SG_IDS; do
      echo "Removing all ingress rules from security group $sg"
      aws ec2 revoke-security-group-ingress --group-id $sg --protocol all --source-group $sg 2>/dev/null || echo "No self-referencing rules to revoke"
      INGRESS_RULES=$(aws ec2 describe-security-groups --group-ids $sg --query 'SecurityGroups[0].IpPermissions' --output json)
      if [[ "$INGRESS_RULES" != "[]" && -n "$INGRESS_RULES" ]]; then
        aws ec2 revoke-security-group-ingress --group-id $sg --ip-permissions "$INGRESS_RULES" 2>/dev/null || echo "No ingress rules to revoke"
      fi
      
      echo "Removing all egress rules from security group $sg"
      EGRESS_RULES=$(aws ec2 describe-security-groups --group-ids $sg --query 'SecurityGroups[0].IpPermissionsEgress' --output json)
      if [[ "$EGRESS_RULES" != "[]" && -n "$EGRESS_RULES" ]]; then
        aws ec2 revoke-security-group-egress --group-id $sg --ip-permissions "$EGRESS_RULES" 2>/dev/null || echo "No egress rules to revoke"
      fi
      
      echo "Deleting security group $sg"
      aws ec2 delete-security-group --group-id $sg || echo "Failed to delete security group $sg"
    done
  else
    echo "No security groups found in VPC $VPC_ID (except default)"
  fi
  
  # Step 8: Delete NAT Gateways
  echo "Finding and deleting NAT Gateways in VPC $VPC_ID..."
  NAT_GATEWAYS=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --query "NatGateways[?State!='deleted'].NatGatewayId" --output text)
  if [[ -n "$NAT_GATEWAYS" ]]; then
    for nat in $NAT_GATEWAYS; do
      echo "Deleting NAT Gateway $nat"
      aws ec2 delete-nat-gateway --nat-gateway-id $nat || echo "Failed to delete NAT Gateway"
    done
    
    # Wait for NAT Gateways to be deleted
    echo "Waiting for NAT Gateways to be deleted..."
    sleep 30
  else
    echo "No NAT Gateways found in VPC $VPC_ID"
  fi
  
  # Step 9: Delete route table associations and route tables
  echo "Finding and deleting route tables in VPC $VPC_ID..."
  ROUTE_TABLES=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" --output text)
  if [[ -n "$ROUTE_TABLES" ]]; then
    for rt in $ROUTE_TABLES; do
      # Get associations
      ASSOCS=$(aws ec2 describe-route-tables --route-table-ids $rt --query "RouteTables[0].Associations[?Main!=\`true\`].RouteTableAssociationId" --output text)
      for assoc in $ASSOCS; do
        echo "Deleting route table association $assoc"
        aws ec2 disassociate-route-table --association-id $assoc || echo "Failed to delete route table association"
      done
      
      echo "Deleting route table $rt"
      aws ec2 delete-route-table --route-table-id $rt || echo "Failed to delete route table"
    done
  else
    echo "No custom route tables found in VPC $VPC_ID"
  fi
  
  # Step 10: Delete Internet Gateway
  echo "Finding and deleting Internet Gateway for VPC $VPC_ID..."
  IGW=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[0].InternetGatewayId" --output text)
  if [[ "$IGW" != "None" && -n "$IGW" ]]; then
    echo "Detaching Internet Gateway $IGW from VPC $VPC_ID"
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC_ID || echo "Failed to detach Internet Gateway"
    echo "Deleting Internet Gateway $IGW"
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW || echo "Failed to delete Internet Gateway"
  else
    echo "No Internet Gateway found for VPC $VPC_ID"
  fi
  
  # Step 11: Delete subnets
  echo "Finding and deleting subnets in VPC $VPC_ID..."
  SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[].SubnetId" --output text)
  if [[ -n "$SUBNETS" ]]; then
    for subnet in $SUBNETS; do
      echo "Deleting subnet $subnet"
      aws ec2 delete-subnet --subnet-id $subnet || echo "Failed to delete subnet"
    done
  else
    echo "No subnets found in VPC $VPC_ID"
  fi
  
  # Step 12: Delete VPC
  echo "Deleting VPC $VPC_ID"
  aws ec2 delete-vpc --vpc-id $VPC_ID || echo "Failed to delete VPC"
done

if [[ -z "$VPC_IDS" ]]; then
  echo "No VPCs found related to ${NAME_PREFIX}"
fi

echo "✅ Enhanced VPC cleanup completed"
