# General Variables
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name to be used for resource naming"
  type        = string
  default     = "max-weather"
}

variable "environment" {
  description = "Environment name (e.g., staging, production)"
  type        = string
  
  validation {
    condition     = contains(["staging", "production", "dev"], var.environment)
    error_message = "Environment must be staging, production, or dev."
  }
}

# VPC Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets (cost optimization)"
  type        = bool
  default     = false
}

# EKS Variables
variable "eks_cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.31"
}

variable "eks_cluster_endpoint_public_access" {
  description = "Enable public access to EKS cluster endpoint"
  type        = bool
  default     = true
}

variable "eks_node_groups" {
  description = "Configuration for EKS managed node groups"
  type = map(object({
    desired_size   = number
    min_size       = number
    max_size       = number
    instance_types = list(string)
    capacity_type  = string
    disk_size      = number
    labels         = map(string)
    taints         = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
  
  default = {
    general = {
      desired_size   = 3
      min_size       = 2
      max_size       = 6
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      disk_size      = 50
      labels = {
        role = "general"
      }
      taints = []
    }
  }
}

# ECR Variables
variable "ecr_repositories" {
  description = "List of ECR repositories to create"
  type        = list(string)
  default     = ["weather-api"]
}

# CloudWatch Variables
variable "cloudwatch_log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

variable "alarm_email_endpoints" {
  description = "Email addresses to receive CloudWatch alarms"
  type        = list(string)
  default     = []
}

# Cognito Variables
variable "cognito_callback_urls" {
  description = "Callback URLs for Cognito user pool"
  type        = list(string)
  default     = ["https://api.kwangle.weather/callback"]
}

variable "cognito_logout_urls" {
  description = "Logout URLs for Cognito user pool"
  type        = list(string)
  default     = ["https://api.kwangle.weather/logout"]
}

# API Gateway Variables
variable "api_domain_name" {
  description = "Custom domain name for API Gateway"
  type        = string
  default     = "api.kwangle.weather"
}

variable "api_stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "v1"
}
