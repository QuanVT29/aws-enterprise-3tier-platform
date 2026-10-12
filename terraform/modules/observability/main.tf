# 1. INCIDENT ROUTING & SNS ALERTING TOPIC 
resource "aws_sns_topic" "alerts" {
  name = "${var.environment}-enterprise-incident-alerts"

  tags = {
    Name        = "${var.environment}-incident-alerts"
    Environment = var.environment
  }
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}



# 2. CLOUDWATCH ALARMS 

# Alarm 1: CPU utilization > 80% 
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.environment}-Enterprise-App-HighCPU-Alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Triggers when ASG average CPU utilization exceeds 80%. Runbook: docs/incident-runbook.md#high-cpu"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }
}

# Alarm 2: Application generates 500 errors (Captured from Log Metric Filter)
resource "aws_cloudwatch_metric_alarm" "http_500" {
  alarm_name          = "${var.environment}-Enterprise-App-High500Errors-Alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Error500Count"
  namespace           = "CustomApp/Diagnostics"
  period              = 60
  statistic           = "Sum"
  threshold           = 3
  alarm_description   = "Triggers when application returns >= 3 HTTP 500 exceptions in 1 minute. Runbook: docs/incident-runbook.md#http-500"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
}

# Alarm 3: Synthetic Canary failed (Availability Drop)
resource "aws_cloudwatch_metric_alarm" "canary_failure" {
  alarm_name          = "${var.environment}-Enterprise-Canary-Availability-Alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "SuccessPercent"
  namespace           = "CloudWatchSynthetics"
  period              = 60
  statistic           = "Average"
  threshold           = 100
  alarm_description   = "Triggers when outside-in availability probe drops below 100%. Runbook: docs/incident-runbook.md#canary-fail"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    CanaryName = aws_synthetics_canary.app_canary.name
  }
}

# 3. DASHBOARD-AS-CODE (SINGLE PANE OF GLASS)
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "Enterprise-Primary-Observability-Hub"

  dashboard_body = jsonencode({
    widgets = [
      # Widget 1: ALB Traffic & Errors
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", color = "#1f77b4" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum", color = "#d62728" }],
            [".", "HTTPCode_Target_2XX_Count", ".", ".", { stat = "Sum", color = "#2ca02c" }]
          ]
          period = 60
          region = var.aws_region
          title  = "ALB Ingress Traffic & Response Status Codes"
          view   = "timeSeries"
        }
      },
      # Widget 2: ALB Latency (Target Response Time p95)
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "p95", color = "#ff7f0e" }]
          ]
          period = 60
          region = var.aws_region
          title  = "ALB Target Latency (p95 Round-Trip Time)"
          view   = "timeSeries"
        }
      },
      # Widget 3: EC2 Saturation (CPU vs RAM CWAgent)
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.asg_name, { stat = "Average", color = "#9467bd" }],
            ["CWAgent", "mem_used_percent", "AutoScalingGroupName", var.asg_name, { stat = "Average", color = "#8c564b" }]
          ]
          period = 60
          region = var.aws_region
          title  = "EC2 ASG Resource Saturation (CPU vs Memory)"
          view   = "timeSeries"
        }
      },
      # Widget 4: Database Health & Connections
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.db_instance_id, { stat = "Average", color = "#17becf" }],
            [".", "CPUUtilization", ".", ".", { stat = "Average", color = "#e377c2" }]
          ]
          period = 60
          region = var.aws_region
          title  = "Amazon RDS Multi-AZ Active Connections & CPU"
          view   = "timeSeries"
        }
      },
      # Widget 5: Synthetic Canary Heartbeat & Latency
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          metrics = [
            ["CloudWatchSynthetics", "SuccessPercent", "CanaryName", aws_synthetics_canary.app_canary.name, { stat = "Average", color = "#2ca02c" }],
            [".", "Duration", ".", ".", { stat = "Average", color = "#bcbd22", yAxis = "right" }]
          ]
          period = 60
          region = var.aws_region
          title  = "Synthetic Canary Availability (Heartbeat Probe Success % & Latency)"
          view   = "timeSeries"
        }
      }
    ]
  })
}