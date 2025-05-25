# Output values for the pricing agent infrastructure

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "policy_bucket_name" {
  description = "Name of the S3 bucket for pricing policies"
  value       = aws_s3_bucket.policy.id
}

output "inventory_table_name" {
  description = "Name of the DynamoDB table for inventory data"
  value       = aws_dynamodb_table.inventory.name
}

output "pricing_table_name" {
  description = "Name of the DynamoDB table for pricing rules"
  value       = aws_dynamodb_table.pricing.name
}

output "sessions_table_name" {
  description = "Name of the DynamoDB table for session data"
  value       = aws_dynamodb_table.sessions.name
}

output "knowledge_base_id" {
  description = "ID of the Bedrock Knowledge Base (from SSM Parameter)"
  value       = aws_ssm_parameter.kb_id.value
  sensitive   = true
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.main.repository_url
}
