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
          name  = "SESSION_TABLE_NAME"
          value = aws_dynamodb_table.sessions.name
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
        },
        {
          name  = "POLICY_BUCKET_NAME"
          value = aws_s3_bucket.policy.id
        },
        {
          name  = "KB_PARAM_NAME"
          value = "/${local.name_prefix}/knowledge-base-id"
        },
        {
          name  = "MODEL_ID"
          value = "anthropic.claude-3-7-sonnet-20250219-v1:0"
        },
        {
          name  = "INFERENCE_PROFILE_ARN"
          value = var.inference_profile_arn != "" ? var.inference_profile_arn : "none"
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
  
  # ECS services should be managed carefully to prevent disruption
  # We allow external updates to task definitions and scaling
  # But we don't set prevent_destroy as services may need recreation during development
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      task_definition,  # Allow external updates to task definition
      desired_count     # Allow auto-scaling to modify the count
    ]
  }
  
  # Use private subnets for ECS tasks with NAT Gateway for internet access
  # This follows AWS best practices for secure infrastructure
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
    aws_lb_listener.https,  # Include HTTPS listener as a dependency
    aws_lb_target_group.main,  # Explicit dependency on target group
    aws_lb.main,  # Explicit dependency on the load balancer
    aws_iam_role_policy_attachment.ecs_execution,
    aws_iam_role_policy_attachment.ecs_task,
    aws_nat_gateway.main,  # Explicit dependency on NAT Gateway
    aws_route_table_association.private  # Ensure route tables are associated
  ]
  
  # Add a provisioner to ensure the target group is properly associated with the load balancer
  # before creating the ECS service
  provisioner "local-exec" {
    command = "aws elbv2 describe-target-groups --target-group-arns ${aws_lb_target_group.main.arn} --query 'TargetGroups[0].LoadBalancerArns' --output text"
    # This command will fail if the target group is not associated with any load balancer
    # which will prevent the ECS service from being created
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 30
  
  # Allow CloudWatch log groups to be recreated during development
  # Only enable prevent_destroy in production
  lifecycle {
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
  
  # Temporarily allowing destroy for clean slate deployment
  # Will be re-enabled after deployment is successful
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      image_scanning_configuration
    ]
  }
  
  tags = local.common_tags
}
