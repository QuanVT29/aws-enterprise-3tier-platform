resource "aws_wafv2_web_acl" "main" {
  name        = "${var.environment}-alb-waf-web-acl"
  description = "Layer 7 Perimeter Defense for Public ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Rule 1: AWS Managed Common Rule Set (CRS - Path Traversal, LFI, RFI, Command Injection)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-WAF-CRS-Metric"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS Managed Known Bad Inputs Rule Set
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-WAF-BadInputs-Metric"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: AWS Managed SQL Injection (SQLi) Rule Set
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-WAF-SQLi-Metric"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: Custom Volumetric Rate-Based Rule (Anti-DDoS: Limit 300 requests / 5 minutes per IP)
  rule {
    name     = "RateLimit300RequestsPer5Minutes"
    priority = 4

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 300
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-WAF-RateLimit-Metric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.environment}-AlbWebAclTotalMetric"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${var.environment}-alb-waf"
    Environment = var.environment
  }
}