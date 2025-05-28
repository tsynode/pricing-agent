variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "pricing-agent"
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

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 8501
}

variable "container_cpu" {
  description = "CPU units for the container (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "container_memory" {
  description = "Memory for the container in MiB"
  type        = number
  default     = 2048
}

variable "desired_count" {
  description = "Desired count of container instances"
  type        = number
  default     = 1
}

variable "health_check_path" {
  description = "Path for ALB health checks"
  type        = string
  default     = "/_stcore/health"
}

variable "model_id" {
  description = "Bedrock model ID for AI models. Available options: anthropic.claude-opus-4-20250514-v1:0 (Claude Opus 4), anthropic.claude-sonnet-4-20250514-v1:0 (Claude Sonnet 4), anthropic.claude-3-7-sonnet-20250219-v1:0 (Claude 3.7 Sonnet)"
  type        = string
  default     = "anthropic.claude-3-7-sonnet-20250219-v1:0"
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS support"
  type        = string
  default     = null
}

# Inference profile is not needed for Claude 3.7 Sonnet
