variable "environment" {
  description = "Environment name"
  type        = string
}

variable "service_name" {
  description = "Service name for IAM policy"
  type        = string
  default     = "flask-api"
}

variable "s3_bucket_arns" {
  description = "S3 bucket ARNs to grant access to"
  type        = list(string)
  default     = []
}

variable "rds_arns" {
  description = "RDS ARNs to grant access to"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

resource "aws_iam_role" "api_role" {
  name = "${var.environment}-${var.service_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.environment}-${var.service_name}-role"
    Environment = var.environment
  })
}

resource "aws_iam_policy" "api_policy" {
  name        = "${var.environment}-${var.service_name}-policy"
  description = "Policy for ${var.service_name} in ${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = concat(
          var.s3_bucket_arns,
          [for arn in var.s3_bucket_arns : "${arn}/*"]
        )
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Sid    = "SSMRead"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/${var.environment}/*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.environment}-${var.service_name}-policy"
    Environment = var.environment
  })
}

resource "aws_iam_role_policy_attachment" "api_policy_attach" {
  role       = aws_iam_role.api_role.name
  policy_arn = aws_iam_policy.api_policy.arn
}

resource "aws_iam_instance_profile" "api_profile" {
  name = "${var.environment}-${var.service_name}-profile"
  role = aws_iam_role.api_role.name

  tags = merge(var.tags, {
    Name        = "${var.environment}-${var.service_name}-profile"
    Environment = var.environment
  })
}

output "role_arn" {
  description = "IAM role ARN"
  value       = aws_iam_role.api_role.arn
}

output "instance_profile_name" {
  description = "IAM instance profile name"
  value       = aws_iam_instance_profile.api_profile.name
}
