resource "aws_lb" "main" {
  name               = "${var.environment}-public-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.public_subnet_ids

  dynamic "access_logs" {
    for_each = var.access_logs_bucket != null ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      enabled = true
    }
  }

  tags = { Name = "${var.environment}-alb" }
}

resource "aws_lb_target_group" "app" {
  name                 = "${var.environment}-app-tg"
  port                 = var.app_port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "instance"
  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/healthz"
    port                = tostring(var.app_port)
    protocol            = "HTTP"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = { Name = "${var.environment}-app-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Associate WAF (Phase 4): When ARN is provided, create the association; otherwise, skip
resource "aws_wafv2_web_acl_association" "waf_assoc" {
  count        = var.waf_acl_arn != null ? 1 : 0
  resource_arn = aws_lb.main.arn
  web_acl_arn  = var.waf_acl_arn
}


