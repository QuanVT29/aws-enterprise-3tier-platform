#  IAM ROLE FOR CODEDEPLOY 
resource "aws_iam_role" "codedeploy_service" {
  name = "${var.environment}-codedeploy-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codedeploy.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_service" {
  role       = aws_iam_role.codedeploy_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# CODEDEPLOY APPLICATION 
resource "aws_codedeploy_app" "app" {
  name             = "${var.environment}-enterprise-app"
  compute_platform = "Server"
}

# CODEDEPLOY DEPLOYMENT GROUP 
resource "aws_codedeploy_deployment_group" "app" {
  app_name               = aws_codedeploy_app.app.name
  deployment_group_name  = "${var.environment}-enterprise-asg-dg"
  service_role_arn       = aws_iam_role.codedeploy_service.arn
  deployment_config_name = "CodeDeployDefault.OneAtATime"

  autoscaling_groups = [aws_autoscaling_group.app.name]

  # Integrated Load Balancer Target Group: automatically drain connection when updating
  load_balancer_info {
    target_group_info {
      name = element(split("/", var.target_group_arn), 1)
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

output "codedeploy_app_name" {
  value = aws_codedeploy_app.app.name
}

output "codedeploy_deployment_group_name" {
  value = aws_codedeploy_deployment_group.app.deployment_group_name
}