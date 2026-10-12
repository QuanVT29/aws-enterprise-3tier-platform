# Log Group receive log from EC2 instances
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/ec2/enterprise-app"
  retention_in_days = 7

  tags = {
    Name        = "${var.environment}-app-log-group"
    Environment = var.environment
  }
}

# Metric Filter scan error logs 500 from server.js
resource "aws_cloudwatch_log_metric_filter" "http_500_errors" {
  name           = "${var.environment}-http-500-errors"
  log_group_name = aws_cloudwatch_log_group.app_logs.name
  pattern        = "[..., msg = \"*Simulated Fatal Exception*\" || msg = \"*500*\"]"

  metric_transformation {
    name          = "Error500Count"
    namespace     = "CustomApp/Diagnostics"
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}