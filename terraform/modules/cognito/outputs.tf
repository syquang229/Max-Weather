output "user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = aws_cognito_user_pool.main.arn
}

output "user_pool_endpoint" {
  description = "Cognito User Pool endpoint"
  value       = aws_cognito_user_pool.main.endpoint
}

output "user_pool_domain" {
  description = "Cognito User Pool domain"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "app_client_id" {
  description = "Cognito App Client ID"
  value       = aws_cognito_user_pool_client.api_client.id
}

output "app_client_secret" {
  description = "Cognito App Client Secret"
  value       = aws_cognito_user_pool_client.api_client.client_secret
  sensitive   = true
}

output "resource_server_identifier" {
  description = "Resource Server identifier"
  value       = aws_cognito_resource_server.api.identifier
}

output "hosted_ui_url" {
  description = "Cognito Hosted UI URL"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.name}.amazoncognito.com/login?client_id=${aws_cognito_user_pool_client.api_client.id}&response_type=code&redirect_uri=${var.callback_urls[0]}"
}

data "aws_region" "current" {}
