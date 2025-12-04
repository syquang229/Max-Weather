# CloudWatch Module - Logging and Monitoring

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Log Groups
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/eks/test/${var.cluster_name}/application"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-application-logs"
    }
  )
}

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/test/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-cluster-logs"
    }
  )
}

resource "aws_cloudwatch_log_group" "fluent_bit" {
  name              = "/aws/fluent-bit/${var.cluster_name}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-fluent-bit-logs"
    }
  )
}

# SNS Topic for Alarms
resource "aws_sns_topic" "alarms" {
  count = length(var.alarm_email_endpoints) > 0 ? 1 : 0

  name = "${var.project_name}-${var.environment}-alarms"

  tags = var.tags
}

resource "aws_sns_topic_subscription" "alarms" {
  for_each = toset(var.alarm_email_endpoints)

  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = each.value
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EKS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors EKS cluster CPU utilization"
  alarm_actions       = length(var.alarm_email_endpoints) > 0 ? [aws_sns_topic.alarms[0].arn] : []

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "This metric monitors EKS cluster memory utilization"
  alarm_actions       = length(var.alarm_email_endpoints) > 0 ? [aws_sns_topic.alarms[0].arn] : []

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "pod_failures" {
  alarm_name          = "${var.project_name}-${var.environment}-pod-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "pod_number_of_container_restarts"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "This metric monitors pod restart count"
  alarm_actions       = length(var.alarm_email_endpoints) > 0 ? [aws_sns_topic.alarms[0].arn] : []

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = var.tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/EKS", "CPUUtilization", { stat = "Average", label = "CPU Utilization" }],
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "EKS CPU Utilization"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["ContainerInsights", "MemoryUtilization", { stat = "Average", label = "Memory Utilization" }],
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "EKS Memory Utilization"
        }
      },
      {
        type = "log"
        properties = {
          query  = "SOURCE '${aws_cloudwatch_log_group.application.name}' | fields @timestamp, @message | sort @timestamp desc | limit 100"
          region = data.aws_region.current.name
          title  = "Recent Application Logs"
        }
      }
    ]
  })
}

data "aws_region" "current" {}
