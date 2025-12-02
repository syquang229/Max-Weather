variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_link_target_arns" {
  description = "List of Network Load Balancer ARNs for VPC Link"
  type        = list(string)
}

variable "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN for authorization"
  type        = string
}

variable "api_domain_name" {
  description = "Custom domain name for API"
  type        = string
}

variable "stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "v1"
}

variable "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  type        = string
  default     = "internal-nlb.local"  # Placeholder - will be updated after NLB creation
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
