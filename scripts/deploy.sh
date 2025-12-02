#!/bin/bash

###############################################################################
# Max Weather Platform - Deployment Script
# 
# This script deploys/updates the Weather API application to EKS
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Configuration
ENVIRONMENT=${1:-production}
IMAGE_TAG=${2:-latest}
AWS_REGION="us-east-1"
NAMESPACE="default"
APP_NAME="weather-api"

print_header "Deploying Max Weather API - ${ENVIRONMENT}"

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_REPOSITORY="max-weather/weather-api"
FULL_IMAGE="${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"

echo "Environment: ${ENVIRONMENT}"
echo "Image: ${FULL_IMAGE}"
echo ""

# Build Docker image
print_warning "Building Docker image..."
cd application/weather-api
docker build -t "${APP_NAME}:${IMAGE_TAG}" .
cd ../..
print_success "Image built successfully"

# Tag for ECR
print_warning "Tagging image for ECR..."
docker tag "${APP_NAME}:${IMAGE_TAG}" "${FULL_IMAGE}"
print_success "Image tagged"

# Login to ECR
print_warning "Logging in to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | \
    docker login --username AWS --password-stdin ${ECR_REGISTRY}
print_success "Logged in to ECR"

# Push to ECR
print_warning "Pushing image to ECR..."
docker push "${FULL_IMAGE}"
print_success "Image pushed to ECR"

# Update kubeconfig
print_warning "Configuring kubectl..."
CLUSTER_NAME="max-weather-${ENVIRONMENT}-cluster"
aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
print_success "kubectl configured"

# Update deployment
print_warning "Updating Kubernetes deployment..."
kubectl set image deployment/${APP_NAME} \
    ${APP_NAME}=${FULL_IMAGE} \
    -n ${NAMESPACE}
print_success "Deployment updated"

# Wait for rollout
print_warning "Waiting for rollout to complete..."
kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=10m
print_success "Rollout complete!"

# Verify deployment
print_header "Deployment Verification"

echo "Pods:"
kubectl get pods -l app=${APP_NAME} -n ${NAMESPACE}

echo -e "\nService:"
kubectl get svc ${APP_NAME}-service -n ${NAMESPACE}

echo -e "\nHPA Status:"
kubectl get hpa ${APP_NAME}-hpa -n ${NAMESPACE}

echo -e "\nIngress:"
kubectl get ingress weather-api-ingress -n ${NAMESPACE}

# Health check
print_warning "Running health check..."
sleep 10

POD_NAME=$(kubectl get pods -l app=${APP_NAME} -n ${NAMESPACE} -o jsonpath='{.items[0].metadata.name}')
if kubectl exec ${POD_NAME} -n ${NAMESPACE} -- wget -qO- http://localhost:8000/health > /dev/null 2>&1; then
    print_success "Health check passed!"
else
    print_warning "Health check failed - but deployment may still be starting up"
fi

print_header "Deployment Complete!"
echo "Image: ${FULL_IMAGE}"
echo "Environment: ${ENVIRONMENT}"
echo -e "\nTo view logs:"
echo "  kubectl logs -f deployment/${APP_NAME} -n ${NAMESPACE}"
echo -e "\nTo rollback if needed:"
echo "  kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}"

print_success "Deployment successful! 🚀"
