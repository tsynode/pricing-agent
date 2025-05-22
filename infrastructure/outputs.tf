output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.streamlit.dns_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository for the Streamlit application"
  value       = aws_ecr_repository.streamlit.repository_url
}

output "sqs_queue_url" {
  description = "URL of the SQS queue for batch processing"
  value       = aws_sqs_queue.pricing_batch.url
}

output "sqs_dlq_url" {
  description = "URL of the SQS dead-letter queue"
  value       = aws_sqs_queue.pricing_batch_dlq.url
}

output "dynamodb_product_financials_table" {
  description = "Name of the DynamoDB product financials table"
  value       = aws_dynamodb_table.product_financials.name
}

output "dynamodb_inventory_table" {
  description = "Name of the DynamoDB inventory table"
  value       = aws_dynamodb_table.inventory.name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for pricing policies"
  value       = aws_s3_bucket.pricing_policies.bucket
}

output "bedrock_agent_id" {
  description = "ID of the Bedrock agent"
  value       = module.bedrock.agent_id
}

output "bedrock_agent_alias_id" {
  description = "ID of the Bedrock agent alias"
  value       = module.bedrock.agent_alias_id
}

output "bedrock_knowledge_base_id" {
  description = "ID of the Bedrock knowledge base"
  value       = module.bedrock.knowledge_base_id
}

output "bedrock_model_id" {
  description = "ID of the Bedrock model"
  value       = var.bedrock_model_id
}

output "bedrock_embedding_model_id" {
  description = "ID of the Bedrock embedding model"
  value       = var.bedrock_embedding_model_id
}

output "lambda_inventory_scanner_arn" {
  description = "ARN of the inventory scanner Lambda function"
  value       = aws_lambda_function.inventory_scanner.arn
}

output "lambda_pricing_tools_arn" {
  description = "ARN of the pricing tools Lambda function"
  value       = aws_lambda_function.pricing_tools.arn
}
