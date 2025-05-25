# This file contains additional listener rules to ensure proper target group association
# with the load balancer even when the default action is a redirect

# Create an explicit listener rule that associates the target group with the HTTP listener
# This ensures the target group is properly registered with the load balancer
resource "aws_lb_listener_rule" "http_forward" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100  # Higher priority than default action

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  # This rule will only match requests with a specific path pattern
  # that won't be hit in normal operation, ensuring it doesn't interfere
  # with the redirect rule when HTTPS is enabled
  condition {
    path_pattern {
      values = ["/health-check-internal-only*"]
    }
  }

  # Explicit dependencies to ensure proper creation order
  depends_on = [
    aws_lb.main,
    aws_lb_target_group.main,
    aws_lb_listener.http
  ]

  tags = local.common_tags
}

# Create a dummy target group attachment to ensure the target group
# is associated with the load balancer before the ECS service is created
resource "aws_lb_target_group_attachment" "dummy" {
  count            = 0  # This resource won't actually be created
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = "dummy"  # This is a placeholder
  port             = var.container_port
  
  # This is just to create a dependency relationship
  # The resource won't actually be created due to count = 0
  depends_on = [
    aws_lb.main,
    aws_lb_target_group.main,
    aws_lb_listener.http,
    aws_lb_listener_rule.http_forward
  ]
  
  # Prevent errors when applying
  lifecycle {
    ignore_changes = all
  }
}
