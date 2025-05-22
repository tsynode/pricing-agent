resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
  
  enable_deletion_protection = false
  
  # Prevent conflicts with existing load balancers
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      subnets,
      security_groups,
      internal,
      enable_deletion_protection,
      drop_invalid_header_fields
    ]
  }
  
  tags = local.common_tags
}

resource "aws_lb_target_group" "main" {
  name        = "${local.name_prefix}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  
  health_check {
    enabled             = true
    interval            = 30
    path                = var.health_check_path
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    protocol            = "HTTP"
    matcher             = "200"
  }
  
  # Prevent conflicts with existing target groups
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      port,
      protocol,
      vpc_id,
      target_type,
      health_check
    ]
  }
  
  tags = local.common_tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
  
  # Prevent conflicts with existing listeners
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      default_action
    ]
  }
  
  tags = local.common_tags
}

# Uncomment this section if you want to use HTTPS
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = var.certificate_arn
#   
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.main.arn
#   }
#   
#   tags = local.common_tags
# }
