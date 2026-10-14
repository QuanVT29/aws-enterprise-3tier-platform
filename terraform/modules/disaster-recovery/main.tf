# 1. ROUTE 53 HEALTH CHECK (MONITORING PRIMARY SINGAPORE INGRESS) 
resource "aws_route53_health_check" "primary" {
  fqdn              = var.primary_alb_dns
  port              = 80
  type              = "HTTP"
  resource_path     = "/healthz"
  failure_threshold = 3
  request_interval  = 10

  tags = {
    Name        = "${var.environment}-primary-alb-healthcheck"
    Environment = var.environment
  }
}

# 2. ACTIVE-PASSIVE FAILOVER DNS RECORDS (CONDITIONAL ON HOSTED ZONE) 
resource "aws_route53_record" "primary" {
  count   = var.hosted_zone_id != "" ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier  = "${var.environment}-primary-singapore"
  health_check_id = aws_route53_health_check.primary.id

  # Using CNAME or Alias point to Primary ALB DNS
  records = [var.primary_alb_dns]
  ttl     = 60
}

resource "aws_route53_record" "secondary" {
  count   = var.hosted_zone_id != "" ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "${var.environment}-secondary-sydney"

  alias {
    name                   = var.secondary_alb_dns
    zone_id                = var.secondary_alb_zone_id
    evaluate_target_health = true
  }
}