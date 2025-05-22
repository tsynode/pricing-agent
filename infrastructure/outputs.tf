output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.main.repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.main.name
}

output "knowledge_base_id" {
  description = "ID of the Bedrock knowledge base"
  value       = module.bedrock.default_kb_identifier
}

output "session_bucket_name" {
  description = "Name of the S3 bucket for session storage"
  value       = aws_s3_bucket.session.id
}

output "policy_bucket_name" {
  description = "Name of the S3 bucket for policy documents"
  value       = aws_s3_bucket.policy.id
}

output "pricing_table_name" {
  description = "Name of the DynamoDB table for pricing rules"
  value       = aws_dynamodb_table.pricing.name
}

output "inventory_table_name" {
  description = "Name of the DynamoDB table for inventory"
  value       = aws_dynamodb_table.inventory.name
}
