# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc.nat_gateway_ids
}

# EKS Outputs
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "eks_cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "eks_oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = module.eks.oidc_provider_arn
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# ECR Outputs
output "ecr_repository_urls" {
  description = "Map of ECR repository URLs"
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "Map of ECR repository ARNs"
  value       = module.ecr.repository_arns
}

# CloudWatch Outputs
output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for application logs"
  value       = module.cloudwatch.application_log_group_name
}

output "cloudwatch_dashboard_url" {
  description = "URL to CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${module.cloudwatch.dashboard_name}"
}

# Cognito Outputs
output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.cognito.user_pool_id
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = module.cognito.user_pool_arn
}

output "cognito_user_pool_endpoint" {
  description = "Cognito User Pool endpoint"
  value       = module.cognito.user_pool_endpoint
}

output "cognito_app_client_id" {
  description = "Cognito App Client ID"
  value       = module.cognito.app_client_id
  sensitive   = true
}

# API Gateway Outputs
output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = module.api_gateway.api_id
}

output "api_gateway_endpoint" {
  description = "API Gateway invoke URL"
  value       = module.api_gateway.api_endpoint
}

output "api_gateway_stage_name" {
  description = "API Gateway stage name"
  value       = module.api_gateway.stage_name
}

# IAM Outputs
output "fluent_bit_role_arn" {
  description = "IAM role ARN for Fluent Bit"
  value       = module.iam.fluent_bit_role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler"
  value       = module.iam.cluster_autoscaler_role_arn
}

output "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = module.iam.aws_load_balancer_controller_role_arn
}

output "ebs_csi_driver_role_arn" {
  description = "IAM role ARN for EBS CSI Driver"
  value       = module.iam.ebs_csi_driver_role_arn
}

# Deployment Information
output "deployment_instructions" {
  description = "Instructions for deploying the application"
  value       = <<-EOT
    
    ============================================
    Max Weather Platform - Deployment Guide
    ============================================
    
    1. Configure kubectl:
       aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}
    
    2. Verify cluster access:
       kubectl cluster-info
       kubectl get nodes
    
    3. Deploy with Helm (Production):
       cd ../helm
       helm lint max-weather/
       helm upgrade --install max-weather-production ./max-weather \
         --namespace weather-production \
         --values ./max-weather/values-production.yaml \
         --create-namespace \
         --atomic \
         --timeout 10m
    
    4. Build and push Docker image:
       cd ../application/weather-api
       docker build -t weather-api:latest .
       docker tag weather-api:latest ${module.ecr.repository_urls["weather-api"]}:latest
       aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${module.ecr.repository_urls["weather-api"]}
       docker push ${module.ecr.repository_urls["weather-api"]}:latest
    
    5. Update deployment with Helm:
       helm upgrade max-weather-production ./helm/max-weather \
         --namespace weather-production \
         --values ./helm/max-weather/values-production.yaml \
         --set weatherApi.image.tag=latest \
         --atomic
    
    6. Check deployment status:
       kubectl rollout status deployment/weather-api -n weather-production
       kubectl get pods -l app=weather-api -n weather-production
       helm status max-weather-production -n weather-production
    
    7. Get LoadBalancer URL:
       kubectl get svc -n ingress-nginx ingress-nginx-controller
    
    8. API Gateway Endpoint:
       ${module.api_gateway.api_endpoint}
    
    9. View logs in CloudWatch:
       https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${module.cloudwatch.dashboard_name}
    
    ============================================
  EOT
}
