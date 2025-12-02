output "application_log_group_name" {
  description = "Application log group name"
  value       = aws_cloudwatch_log_group.application.name
}

output "application_log_group_arn" {
  description = "Application log group ARN"
  value       = aws_cloudwatch_log_group.application.arn
}

output "cluster_log_group_name" {
  description = "Cluster log group name"
  value       = aws_cloudwatch_log_group.cluster.name
}

output "fluent_bit_log_group_name" {
  description = "Fluent Bit log group name"
  value       = aws_cloudwatch_log_group.fluent_bit.name
}

output "dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alarms"
  value       = length(var.alarm_email_endpoints) > 0 ? aws_sns_topic.alarms[0].arn : ""
}
