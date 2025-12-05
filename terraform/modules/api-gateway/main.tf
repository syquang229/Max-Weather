# API Gateway Module

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# IAM Role for API Gateway CloudWatch Logging
resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${var.project_name}-${var.environment}-api-gateway-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# API Gateway Account Settings (for CloudWatch Logs)
resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-${var.environment}-api"
  description = "Weather API Gateway for ${var.project_name}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.tags
}

# VPC Link for private integration
# Note: This will be created after NLB is provisioned by Kubernetes
resource "aws_api_gateway_vpc_link" "main" {
  count = length(var.vpc_link_target_arns) > 0 ? 1 : 0

  name        = "${var.project_name}-${var.environment}-vpc-link"
  description = "VPC Link to internal NLB"
  target_arns = var.vpc_link_target_arns

  tags = var.tags
}

# Cognito Authorizer
resource "aws_api_gateway_authorizer" "cognito" {
  name            = "${var.project_name}-${var.environment}-cognito-authorizer"
  rest_api_id     = aws_api_gateway_rest_api.main.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [var.cognito_user_pool_arn]
  identity_source = "method.request.header.Authorization"
}

# API Gateway Resources
resource "aws_api_gateway_resource" "forecast" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "forecast"
}

resource "aws_api_gateway_resource" "current" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "current"
}

resource "aws_api_gateway_resource" "health" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "health"
}

# GET /forecast
resource "aws_api_gateway_method" "forecast_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.forecast.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  request_parameters = {
    "method.request.querystring.location" = true
  }
}

resource "aws_api_gateway_integration" "forecast_get" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.forecast.id
  http_method = aws_api_gateway_method.forecast_get.http_method

  # Use MOCK integration if no backend configured, otherwise HTTP_PROXY
  type                    = var.nlb_dns_name == "" || var.nlb_dns_name == "internal-nlb.local" ? "MOCK" : "HTTP_PROXY"
  uri                     = var.nlb_dns_name == "" || var.nlb_dns_name == "internal-nlb.local" ? "" : "http://${var.nlb_dns_name}/forecast"
  integration_http_method = var.nlb_dns_name == "" || var.nlb_dns_name == "internal-nlb.local" ? null : "GET"
  connection_type         = length(aws_api_gateway_vpc_link.main) > 0 ? "VPC_LINK" : "INTERNET"
  connection_id           = length(aws_api_gateway_vpc_link.main) > 0 ? aws_api_gateway_vpc_link.main[0].id : null

  request_templates = var.nlb_dns_name == "" || var.nlb_dns_name == "internal-nlb.local" ? {
    "application/json" = jsonencode({
      statusCode = 200
    })
  } : null

  request_parameters = var.nlb_dns_name == "" || var.nlb_dns_name == "internal-nlb.local" ? null : {
    "integration.request.querystring.location" = "method.request.querystring.location"
  }
}

# GET /current
resource "aws_api_gateway_method" "current_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.current.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  request_parameters = {
    "method.request.querystring.location" = true
  }
}

resource "aws_api_gateway_integration" "current_get" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.current.id
  http_method = aws_api_gateway_method.current_get.http_method

  # Use MOCK integration if no backend configured, otherwise HTTP_PROXY
  type                    = var.nlb_dns_name == "" || var.nlb_dns_name == "internal-nlb.local" ? "MOCK" : "HTTP_PROXY"
  uri                     = var.nlb_dns_name == "" || var.nlb_dns_name == "internal-nlb.local" ? "" : "http://${var.nlb_dns_name}/current"
  integration_http_method = var.nlb_dns_name == "" || var.nlb_dns_name == "internal-nlb.local" ? null : "GET"
  connection_type         = length(aws_api_gateway_vpc_link.main) > 0 ? "VPC_LINK" : "INTERNET"
  connection_id           = length(aws_api_gateway_vpc_link.main) > 0 ? aws_api_gateway_vpc_link.main[0].id : null

  request_templates = var.nlb_dns_name == "" || var.nlb_dns_name == "internal-nlb.local" ? {
    "application/json" = jsonencode({
      statusCode = 200
    })
  } : null

  request_parameters = var.nlb_dns_name == "" || var.nlb_dns_name == "internal-nlb.local" ? null : {
    "integration.request.querystring.location" = "method.request.querystring.location"
  }
}

# GET /health (no auth required)
resource "aws_api_gateway_method" "health_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.health.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "health_get" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.health.id
  http_method = aws_api_gateway_method.health_get.http_method

  # Use MOCK integration if no backend configured, otherwise HTTP_PROXY
  type                    = var.nlb_dns_name == "" || var.nlb_dns_name == "internal-nlb.local" ? "MOCK" : "HTTP_PROXY"
  uri                     = var.nlb_dns_name == "" || var.nlb_dns_name == "internal-nlb.local" ? "" : "http://${var.nlb_dns_name}/health"
  integration_http_method = var.nlb_dns_name == "" || var.nlb_dns_name == "internal-nlb.local" ? null : "GET"
  connection_type         = length(aws_api_gateway_vpc_link.main) > 0 ? "VPC_LINK" : "INTERNET"
  connection_id           = length(aws_api_gateway_vpc_link.main) > 0 ? aws_api_gateway_vpc_link.main[0].id : null

  request_templates = var.nlb_dns_name == "" || var.nlb_dns_name == "internal-nlb.local" ? {
    "application/json" = jsonencode({
      statusCode = 200
    })
  } : null
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  depends_on = [
    aws_api_gateway_integration.forecast_get,
    aws_api_gateway_integration.current_get,
    aws_api_gateway_integration.health_get,
  ]

  lifecycle {
    create_before_destroy = true
  }

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.forecast.id,
      aws_api_gateway_resource.current.id,
      aws_api_gateway_resource.health.id,
      aws_api_gateway_method.forecast_get.id,
      aws_api_gateway_method.current_get.id,
      aws_api_gateway_method.health_get.id,
      aws_api_gateway_integration.forecast_get.id,
      aws_api_gateway_integration.current_get.id,
      aws_api_gateway_integration.health_get.id,
    ]))
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.stage_name

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = var.tags

  depends_on = [
    aws_api_gateway_account.main
  ]
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}"
  retention_in_days = 30

  tags = var.tags
}

# API Gateway Method Settings (Throttling & Logging)
resource "aws_api_gateway_method_settings" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = true
    logging_level          = "INFO"
    data_trace_enabled     = true
    throttling_burst_limit = 5000
    throttling_rate_limit  = 10000
  }
}

# Usage Plan
resource "aws_api_gateway_usage_plan" "main" {
  name        = "${var.project_name}-${var.environment}-usage-plan"
  description = "Usage plan for ${var.project_name} API"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }

  quota_settings {
    limit  = 1000000
    period = "MONTH"
  }

  throttle_settings {
    burst_limit = 5000
    rate_limit  = 10000
  }

  tags = var.tags
}

# API Key
resource "aws_api_gateway_api_key" "main" {
  name    = "${var.project_name}-${var.environment}-api-key"
  enabled = true

  tags = var.tags
}

resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.main.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.main.id
}
