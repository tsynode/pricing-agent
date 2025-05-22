###########################
# Lambda Functions
###########################

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "inventory_scanner" {
  name              = "/aws/lambda/${local.name_prefix}-inventory-scanner"
  retention_in_days = 14

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "batch_processor" {
  name              = "/aws/lambda/${local.name_prefix}-batch-processor"
  retention_in_days = 14

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "pricing_tools" {
  name              = "/aws/lambda/${local.name_prefix}-pricing-tools"
  retention_in_days = 14

  tags = local.common_tags
}

# Inventory Scanner Lambda
resource "aws_lambda_function" "inventory_scanner" {
  function_name = "${local.name_prefix}-inventory-scanner"
  description   = "Scans inventory and creates batches for processing"
  
  filename         = "${path.module}/dummy.zip"
  source_code_hash = "dummy-hash-for-validation"
  
  handler     = "lambda_function.lambda_handler"
  runtime     = var.lambda_runtime
  memory_size = var.scanner_lambda_memory
  timeout     = var.scanner_lambda_timeout
  
  role = aws_iam_role.inventory_scanner_lambda.arn
  
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }
  
  environment {
    variables = {
      SQS_QUEUE_URL = aws_sqs_queue.pricing_batch.url
      BATCH_SIZE    = "100"
    }
  }
  
  depends_on = [
    aws_cloudwatch_log_group.inventory_scanner
  ]
  
  tags = local.common_tags
}

# Batch Processor Lambda
resource "aws_lambda_function" "batch_processor" {
  function_name = "${local.name_prefix}-batch-processor"
  description   = "Processes batches of inventory items for pricing compliance"
  
  filename         = "${path.module}/dummy.zip"
  source_code_hash = "dummy-hash-for-validation"
  
  handler     = "lambda_function.lambda_handler"
  runtime     = var.lambda_runtime
  memory_size = var.batch_processor_lambda_memory
  timeout     = var.batch_processor_lambda_timeout
  
  role = aws_iam_role.batch_processor_lambda.arn
  
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }
  
  environment {
    variables = {
      BEDROCK_MODEL_ID = var.bedrock_model_id
      BEDROCK_EMBEDDING_MODEL_ID = var.bedrock_embedding_model_id
      BEDROCK_AGENT_ID = module.bedrock.bedrock_agent.id
      BEDROCK_AGENT_ALIAS_ID = module.bedrock.bedrock_agent_alias.id
      BEDROCK_KNOWLEDGE_BASE_ID = module.bedrock.knowledge_base.id
      AWS_REGION = var.aws_region
    }
  }
  
  depends_on = [
    aws_cloudwatch_log_group.batch_processor
  ]
  
  tags = local.common_tags
}

# Pricing Tools Lambda
resource "aws_lambda_function" "pricing_tools" {
  function_name = "${local.name_prefix}-pricing-tools"
  description   = "Provides pricing tools for the Bedrock agent"
  
  filename         = "${path.module}/dummy.zip"
  source_code_hash = "dummy-hash-for-validation"
  
  handler     = "lambda_function.lambda_handler"
  runtime     = var.lambda_runtime
  memory_size = var.pricing_tools_lambda_memory
  timeout     = var.pricing_tools_lambda_timeout
  
  role = aws_iam_role.pricing_tools_lambda.arn
  
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }
  
  environment {
    variables = {
      PRODUCT_FINANCIALS_TABLE = aws_dynamodb_table.product_financials.name
      INVENTORY_TABLE = aws_dynamodb_table.inventory.name
    }
  }
  
  depends_on = [
    aws_cloudwatch_log_group.pricing_tools
  ]
  
  tags = local.common_tags
}

# EventBridge Rule for Scheduled Scanning
resource "aws_cloudwatch_event_rule" "scan_schedule" {
  name                = "${local.name_prefix}-scan-schedule"
  description         = "Triggers inventory scanning every 10 minutes"
  schedule_expression = "cron(*/10 * * * ? *)"
  
  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "scan_schedule" {
  rule      = aws_cloudwatch_event_rule.scan_schedule.name
  target_id = "InvokeInventoryScanner"
  arn       = aws_lambda_function.inventory_scanner.arn
  
  input = jsonencode({
    source    = "scheduled"
    timestamp = "#{aws:timestamp}"
  })
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.inventory_scanner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scan_schedule.arn
}

# SQS Trigger for Batch Processor Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.pricing_batch.arn
  function_name    = aws_lambda_function.batch_processor.function_name
  batch_size       = var.sqs_batch_size
  enabled          = true
}
