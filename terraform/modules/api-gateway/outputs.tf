output "api_id" {
  description = "API Gateway ID"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_arn" {
  description = "API Gateway ARN"
  value       = aws_api_gateway_rest_api.main.arn
}

output "api_endpoint" {
  description = "API Gateway invoke URL"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "stage_name" {
  description = "API Gateway stage name"
  value       = aws_api_gateway_stage.main.stage_name
}

output "vpc_link_id" {
  description = "VPC Link ID"
  value       = aws_api_gateway_vpc_link.main.id
}

output "authorizer_id" {
  description = "Cognito Authorizer ID"
  value       = aws_api_gateway_authorizer.cognito.id
}

output "api_key_value" {
  description = "API Key value"
  value       = aws_api_gateway_api_key.main.value
  sensitive   = true
}

output "usage_plan_id" {
  description = "Usage Plan ID"
  value       = aws_api_gateway_usage_plan.main.id
}
