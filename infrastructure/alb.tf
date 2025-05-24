# Application Load Balancer for the ECS service
# This ALB routes external traffic to the ECS tasks
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false  # Internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id  # ALB must be in public subnets
  
  enable_deletion_protection = false
  
  # Prevent conflicts with existing load balancers
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      # Only ignore these specific attributes, not the entire resource
      name,
      internal,
      enable_deletion_protection,
      drop_invalid_header_fields
    ]
  }
  
  # Explicit dependency on VPC, public subnets, and security group
  depends_on = [
    aws_vpc.main,
    aws_subnet.public,
    aws_security_group.alb,
    aws_internet_gateway.main  # ALB needs internet access
  ]
  
  tags = local.common_tags
}

# Target group for the ALB to route traffic to ECS tasks
resource "aws_lb_target_group" "main" {
  name        = "${local.name_prefix}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id  # Must be in the same VPC as the ALB and ECS tasks
  target_type = "ip"  # For Fargate tasks, which use the awsvpc network mode
  
  # Health check configuration
  # Adjusted for Streamlit application with longer timeouts
  health_check {
    enabled             = true
    interval            = 60
    path                = var.health_check_path
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 30
    protocol            = "HTTP"
    matcher             = "200,302"  # Streamlit may return redirects
  }
  
  # Prevent conflicts with existing target groups
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      # Only ignore these specific attributes, not the entire resource
      name,
      port,
      protocol,
      target_type,
      health_check
    ]
  }
  
  # Explicit dependency on VPC
  depends_on = [aws_vpc.main]
  
  tags = local.common_tags
}

# HTTP listener for the ALB
# Either forwards traffic directly or redirects to HTTPS based on configuration
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    # If HTTPS is enabled and we have a domain, redirect to HTTPS
    # Otherwise, forward traffic directly to the target group
    type = var.enable_https && var.domain_name != "" ? "redirect" : "forward"
    
    dynamic "redirect" {
      for_each = var.enable_https && var.domain_name != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
    
    dynamic "forward" {
      for_each = !var.enable_https || var.domain_name == "" ? [1] : []
      content {
        target_group_arn = aws_lb_target_group.main.arn
      }
    }
  }
  
  # Prevent conflicts with existing listeners
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      # Only ignore the default_action, not the entire resource
      default_action
    ]
  }
  
  # Explicit dependency on ALB
  depends_on = [aws_lb.main]
  
  tags = local.common_tags
}

# HTTPS listener for the ALB (only created if HTTPS is enabled and domain is provided)
# Routes incoming HTTPS traffic to the target group
resource "aws_lb_listener" "https" {
  count = var.enable_https && var.domain_name != "" ? 1 : 0
  
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = local.certificate_arn
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
  
  # Prevent conflicts with existing listeners
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      # Only ignore the default_action, not the entire resource
      default_action
    ]
  }
  
  # Explicit dependency on ALB and target group
  depends_on = [
    aws_lb.main,
    aws_lb_target_group.main
  ]
  
  tags = local.common_tags
}
