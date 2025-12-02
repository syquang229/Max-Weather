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
APP_NAME="weather-api"
HELM_RELEASE="max-weather"
HELM_CHART="./helm/max-weather"

# Determine values file based on environment
if [ "$ENVIRONMENT" = "staging" ]; then
    VALUES_FILE="${HELM_CHART}/values-staging.yaml"
    NAMESPACE="weather-staging"
else
    VALUES_FILE="${HELM_CHART}/values-production.yaml"
fi

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

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo "Error: Helm is not installed. Please install Helm 3.x"
    exit 1
fi

# Validate Helm chart
print_warning "Validating Helm chart..."
helm lint ${HELM_CHART}
print_success "Helm chart validated"

# Show what will change (dry-run)
print_warning "Previewing changes with Helm diff..."
helm diff upgrade ${HELM_RELEASE} ${HELM_CHART} \
    --namespace ${NAMESPACE} \
    --values ${VALUES_FILE} \
    --set image.tag=${IMAGE_TAG} \
    --allow-unreleased || true

echo ""
read -p "Continue with deployment? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    print_warning "Deployment cancelled"
    exit 0
fi

# Deploy with Helm
print_warning "Deploying with Helm (atomic upgrade)..."
helm upgrade --install ${HELM_RELEASE} ${HELM_CHART} \
    --namespace ${NAMESPACE} \
    --values ${VALUES_FILE} \
    --set image.tag=${IMAGE_TAG} \
    --atomic \
    --timeout 10m \
    --wait
print_success "Helm upgrade complete!"

# Wait for rollout
print_warning "Verifying rollout status..."
kubectl rollout status deployment/max-weather -n ${NAMESPACE} --timeout=10m
print_success "Rollout complete!"

# Verify deployment
print_header "Deployment Verification"

echo "Helm Release Status:"
helm status ${HELM_RELEASE} -n ${NAMESPACE}

echo -e "\nHelm Release History:"
helm history ${HELM_RELEASE} -n ${NAMESPACE}

echo -e "\nPods:"
kubectl get pods -l app.kubernetes.io/name=max-weather -n ${NAMESPACE}

echo -e "\nService:"
kubectl get svc -l app.kubernetes.io/name=max-weather -n ${NAMESPACE}

echo -e "\nHPA Status:"
kubectl get hpa -n ${NAMESPACE}

echo -e "\nIngress:"
kubectl get ingress -n ${NAMESPACE}

# Health check
print_warning "Running health check..."
sleep 10

POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=max-weather -n ${NAMESPACE} -o jsonpath='{.items[0].metadata.name}')
if kubectl exec ${POD_NAME} -n ${NAMESPACE} -- wget -qO- http://localhost:8000/health > /dev/null 2>&1; then
    print_success "Health check passed!"
else
    print_warning "Health check failed - but deployment may still be starting up"
fi

print_header "Deployment Complete!"
echo "Helm Release: ${HELM_RELEASE}"
echo "Image: ${FULL_IMAGE}"
echo "Environment: ${ENVIRONMENT}"
echo "Values File: ${VALUES_FILE}"
echo -e "\nTo view logs:"
echo "  kubectl logs -f deployment/max-weather -n ${NAMESPACE}"
echo -e "\nTo rollback if needed:"
echo "  helm rollback ${HELM_RELEASE} -n ${NAMESPACE}"
echo "  # Or to specific revision:"
echo "  helm rollback ${HELM_RELEASE} <revision> -n ${NAMESPACE}"
echo -e "\nTo view release history:"
echo "  helm history ${HELM_RELEASE} -n ${NAMESPACE}"

print_success "Deployment successful! 🚀"
