#!/bin/bash
# Script to specifically clean up ALB resources that weren't properly removed
# This is a targeted cleanup for the ALB and target group that are causing deployment issues

set -e

# Environment to clean up
ENVIRONMENT="staging"
PROJECT="pricing-agent"
NAME_PREFIX="${PROJECT}-${ENVIRONMENT}"
REGION="${AWS_REGION:-us-east-1}"

echo "🧹 Cleaning up ALB resources for ${NAME_PREFIX}..."

# Find and delete target group
echo "Finding target groups with name ${NAME_PREFIX}-tg..."
TARGET_GROUPS=$(aws elbv2 describe-target-groups --region $REGION --query "TargetGroups[?starts_with(TargetGroupName, '${NAME_PREFIX}-tg')].TargetGroupArn" --output text)

if [[ -n "$TARGET_GROUPS" ]]; then
  for tg in $TARGET_GROUPS; do
    echo "Deleting target group $tg"
    aws elbv2 delete-target-group --region $REGION --target-group-arn "$tg" || echo "Failed to delete target group"
  done
else
  echo "No target groups found with name ${NAME_PREFIX}-tg"
fi

# Find and delete ALB
echo "Finding ALB with name ${NAME_PREFIX}-alb..."
ALB_ARN=$(aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[?starts_with(LoadBalancerName, '${NAME_PREFIX}-alb')].LoadBalancerArn" --output text)

if [[ -n "$ALB_ARN" && "$ALB_ARN" != "None" ]]; then
  # Get listeners
  echo "Finding listeners for ALB $ALB_ARN..."
  LISTENERS=$(aws elbv2 describe-listeners --region $REGION --load-balancer-arn "$ALB_ARN" --query "Listeners[].ListenerArn" --output text)
  
  # Delete listeners first
  if [[ -n "$LISTENERS" ]]; then
    for listener in $LISTENERS; do
      echo "Deleting listener $listener"
      aws elbv2 delete-listener --region $REGION --listener-arn "$listener" || echo "Failed to delete listener"
    done
  else
    echo "No listeners found for ALB $ALB_ARN"
  fi
  
  # Modify ALB to disable deletion protection
  echo "Disabling deletion protection for ALB $ALB_ARN..."
  aws elbv2 modify-load-balancer-attributes --region $REGION --load-balancer-arn "$ALB_ARN" --attributes Key=deletion_protection.enabled,Value=false || echo "Failed to disable deletion protection"
  
  # Delete the ALB
  echo "Deleting ALB $ALB_ARN..."
  aws elbv2 delete-load-balancer --region $REGION --load-balancer-arn "$ALB_ARN" || echo "Failed to delete ALB"
else
  echo "No ALB found with name ${NAME_PREFIX}-alb"
fi

echo "✅ ALB cleanup completed for ${NAME_PREFIX}"
