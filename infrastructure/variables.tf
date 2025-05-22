variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "pricing-agent"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "lambda_runtime" {
  description = "Runtime for Lambda functions"
  type        = string
  default     = "python3.11"
}

variable "scanner_lambda_memory" {
  description = "Memory allocation for Inventory Scanner Lambda"
  type        = number
  default     = 512
}

variable "scanner_lambda_timeout" {
  description = "Timeout for Inventory Scanner Lambda in seconds"
  type        = number
  default     = 300 # 5 minutes
}

variable "batch_processor_lambda_memory" {
  description = "Memory allocation for Batch Processor Lambda"
  type        = number
  default     = 256
}

variable "batch_processor_lambda_timeout" {
  description = "Timeout for Batch Processor Lambda in seconds"
  type        = number
  default     = 180 # 3 minutes
}

variable "pricing_tools_lambda_memory" {
  description = "Memory allocation for Pricing Tools Lambda"
  type        = number
  default     = 256
}

variable "pricing_tools_lambda_timeout" {
  description = "Timeout for Pricing Tools Lambda in seconds"
  type        = number
  default     = 120 # 2 minutes
}

variable "sqs_batch_size" {
  description = "Number of messages to process per Lambda invocation"
  type        = number
  default     = 10
}

variable "sqs_visibility_timeout" {
  description = "Visibility timeout for SQS messages in seconds"
  type        = number
  default     = 300 # 5 minutes
}

variable "sqs_message_retention" {
  description = "Message retention period in seconds"
  type        = number
  default     = 1209600 # 14 days
}

variable "sqs_max_receive_count" {
  description = "Maximum number of receives before sending to DLQ"
  type        = number
  default     = 3
}

variable "ecs_task_cpu" {
  description = "CPU units for ECS task"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "Memory for ECS task in MB"
  type        = number
  default     = 512
}

variable "ecs_desired_count" {
  description = "Desired count of ECS tasks"
  type        = number
  default     = 1
}

variable "ecs_max_count" {
  description = "Maximum count of ECS tasks"
  type        = number
  default     = 2
}

variable "streamlit_container_port" {
  description = "Container port for Streamlit application"
  type        = number
  default     = 8501
}

variable "bedrock_model_id" {
  description = "Amazon Bedrock model ID for agent"
  type        = string
  default     = "anthropic.claude-3-7-sonnet-20250219-v1:0"
}

variable "bedrock_embedding_model_id" {
  description = "Amazon Bedrock model ID for embeddings"
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}
