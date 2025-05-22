resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  
  # Prevent conflicts with existing clusters
  lifecycle {
    create_before_destroy = true
  }
  
  tags = local.common_tags
}

resource "aws_ecs_task_definition" "main" {
  family                   = "${local.name_prefix}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  
  # Task definitions are immutable, so create_before_destroy ensures the new one is created first
  lifecycle {
    create_before_destroy = true
  }
  
  container_definitions = jsonencode([
    {
      name      = "${local.name_prefix}-container"
      image     = "${aws_ecr_repository.main.repository_url}:latest"
      essential = true
      
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "SESSION_BUCKET_NAME"
          value = aws_s3_bucket.session.id
        },
        {
          name  = "PRICING_TABLE_NAME"
          value = aws_dynamodb_table.pricing.name
        },
        {
          name  = "INVENTORY_TABLE_NAME"
          value = aws_dynamodb_table.inventory.name
        },
        {
          name  = "NAME_PREFIX"
          value = local.name_prefix
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.main.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
  
  tags = local.common_tags
}

resource "aws_ecs_service" "main" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  
  # This prevents conflicts with existing services and allows external updates
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      task_definition,  # Allow external updates to task definition
      desired_count,    # Allow auto-scaling to modify the count
      load_balancer     # Handle load balancer attachment changes gracefully
    ]
  }
  
  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "${local.name_prefix}-container"
    container_port   = var.container_port
  }
  
  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_execution,
    aws_iam_role_policy_attachment.ecs_task
  ]
  
  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 30
  
  # Prevent conflicts with existing log groups
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      retention_in_days,
      kms_key_id
    ]
  }
  
  tags = local.common_tags
}

resource "aws_ecr_repository" "main" {
  name                 = "${local.name_prefix}"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  # Prevent conflicts with existing repositories
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      image_scanning_configuration
    ]
  }
  
  tags = local.common_tags
}
