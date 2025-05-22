resource "aws_sqs_queue" "pricing_batch_dlq" {
  name                      = "${local.name_prefix}-pricing-batch-dlq"
  message_retention_seconds = var.sqs_message_retention
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-pricing-batch-dlq"
    }
  )
}

resource "aws_sqs_queue" "pricing_batch" {
  name                      = "${local.name_prefix}-pricing-batch"
  visibility_timeout_seconds = var.sqs_visibility_timeout
  message_retention_seconds = var.sqs_message_retention
  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.pricing_batch_dlq.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-pricing-batch"
    }
  )
}
