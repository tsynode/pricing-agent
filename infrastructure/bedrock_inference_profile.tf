# Bedrock Inference Profile for Claude 4 Opus
# This is needed because Claude 4 Opus requires an inference profile when using on-demand throughput

resource "aws_bedrock_inference_profile" "claude_opus" {
  name        = "pricing-agent-${var.environment}-${replace(var.model_id, ":", "-")}"
  model_arn   = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.model_id}"
  
  # Standard throughput configuration for on-demand usage
  inference_profile_configuration {
    type = "ON_DEMAND"
  }
  
  tags = local.common_tags
}

# Output the inference profile ARN for reference
output "inference_profile_arn" {
  description = "ARN of the Bedrock inference profile"
  value       = aws_bedrock_inference_profile.claude_opus.arn
  sensitive   = true
}
