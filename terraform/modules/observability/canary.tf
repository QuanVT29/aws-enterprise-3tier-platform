# S3 Bucket store images and logs of Canary
resource "aws_s3_bucket" "canary_artifacts" {
  bucket_prefix = "enterprise-canary-artifacts-"
  force_destroy = true

  tags = {
    Name        = "${var.environment}-canary-artifacts"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "canary" {
  bucket                  = aws_s3_bucket.canary_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM Role granting permissions for Synthetic Canary execution
resource "aws_iam_role" "canary_role" {
  name = "${var.environment}-synthetics-canary-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "canary_policy" {
  name = "${var.environment}-synthetics-execution-policy"
  role = aws_iam_role.canary_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.canary_artifacts.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:GetBucketLocation"
        Resource = aws_s3_bucket.canary_artifacts.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = "cloudwatch:PutMetricData"
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" : "CloudWatchSynthetics"
          }
        }
      }
    ]
  })
}

# Packaging inline NodeJS Puppeteer code for Canary Probe
data "archive_file" "canary_zip" {
  type        = "zip"
  output_path = "${path.module}/canary.zip"

  source {
    content = <<-EOF
      const synthetics = require('Synthetics');
      const log = require('SyntheticsLogger');

      const heartbeatScript = async function () {
        const targetUrl = "http://${var.alb_dns_name}/healthz";
        log.info('Running health check ping to: ' + targetUrl);

        let requestOptions = {
          hostname: "${var.alb_dns_name}",
          method: 'GET',
          path: '/healthz',
          port: 80,
          protocol: 'http:'
        };

        let stepConfig = {
          stepName: 'VerifyEndpointAlive',
          requestOptions: requestOptions
        };

        await synthetics.executeHttpStep('HeartbeatProbe', requestOptions, async function (res) {
          if (res.statusCode !== 200) {
            throw new Error('Canary probe failed with HTTP status code: ' + res.statusCode);
          }
        });
      };

      exports.handler = async () => {
        return await heartbeatScript();
      };
    EOF
    filename = "nodejs/node_modules/canary_script.js"
  }
}

# Synthetics Canary running every 1 minute
resource "aws_synthetics_canary" "app_canary" {
  name                 = "app-health-canary"
  artifact_s3_location = "s3://${aws_s3_bucket.canary_artifacts.bucket}/"
  execution_role_arn   = aws_iam_role.canary_role.arn
  handler              = "canary_script.handler"
  zip_file             = data.archive_file.canary_zip.output_path
  runtime_version      = "syn-nodejs-puppeteer-9.1"

  schedule {
    expression = "rate(1 minute)"
  }

  run_config {
    timeout_in_seconds = 60
  }

  tags = {
    Name        = "${var.environment}-app-health-canary"
    Environment = var.environment
  }
}