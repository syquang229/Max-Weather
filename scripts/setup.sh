#!/bin/bash

###############################################################################
# Max Weather Platform - Setup Script
# 
# This script helps set up the Max Weather infrastructure on AWS
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_deps=0
    
    # Check AWS CLI
    if command -v aws &> /dev/null; then
        print_success "AWS CLI installed: $(aws --version)"
    else
        print_error "AWS CLI not found. Please install: https://aws.amazon.com/cli/"
        missing_deps=1
    fi
    
    # Check Terraform
    if command -v terraform &> /dev/null; then
        print_success "Terraform installed: $(terraform version | head -n 1)"
    else
        print_error "Terraform not found. Please install: https://www.terraform.io/downloads"
        missing_deps=1
    fi
    
    # Check kubectl
    if command -v kubectl &> /dev/null; then
        print_success "kubectl installed: $(kubectl version --client --short 2>/dev/null || echo 'kubectl')"
    else
        print_error "kubectl not found. Please install: https://kubernetes.io/docs/tasks/tools/"
        missing_deps=1
    fi
    
    # Check Helm
    if command -v helm &> /dev/null; then
        print_success "Helm installed: $(helm version --short)"
    else
        print_error "Helm not found. Please install: https://helm.sh/docs/intro/install/"
        missing_deps=1
    fi
    
    # Check Docker
    if command -v docker &> /dev/null; then
        print_success "Docker installed: $(docker --version)"
    else
        print_error "Docker not found. Please install: https://docs.docker.com/get-docker/"
        missing_deps=1
    fi
    
    if [ $missing_deps -eq 1 ]; then
        print_error "Please install missing prerequisites before continuing."
        exit 1
    fi
    
    print_success "All prerequisites satisfied!"
}

configure_aws() {
    print_header "AWS Configuration"
    
    # Check AWS credentials
    if aws sts get-caller-identity &> /dev/null; then
        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
        print_success "AWS credentials configured"
        echo "Account ID: $AWS_ACCOUNT_ID"
        echo "User/Role: $AWS_USER"
    else
        print_error "AWS credentials not configured. Run 'aws configure' first."
        exit 1
    fi
}

create_terraform_backend() {
    print_header "Creating Terraform Backend (S3 + DynamoDB)"
    
    BUCKET_NAME="max-weather-terraform-state"
    TABLE_NAME="max-weather-terraform-locks"
    REGION="us-east-1"
    
    # Create S3 bucket
    if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
        print_warning "Creating S3 bucket: ${BUCKET_NAME}"
        aws s3 mb "s3://${BUCKET_NAME}" --region ${REGION}
        
        # Enable versioning
        aws s3api put-bucket-versioning \
            --bucket ${BUCKET_NAME} \
            --versioning-configuration Status=Enabled
        
        # Enable encryption
        aws s3api put-bucket-encryption \
            --bucket ${BUCKET_NAME} \
            --server-side-encryption-configuration '{
                "Rules": [{
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }]
            }'
        
        print_success "S3 bucket created: ${BUCKET_NAME}"
    else
        print_success "S3 bucket already exists: ${BUCKET_NAME}"
    fi
    
    # Create DynamoDB table
    if aws dynamodb describe-table --table-name ${TABLE_NAME} --region ${REGION} &> /dev/null; then
        print_success "DynamoDB table already exists: ${TABLE_NAME}"
    else
        print_warning "Creating DynamoDB table: ${TABLE_NAME}"
        aws dynamodb create-table \
            --table-name ${TABLE_NAME} \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
            --region ${REGION}
        
        print_success "DynamoDB table created: ${TABLE_NAME}"
    fi
}

setup_terraform_vars() {
    print_header "Setting up Terraform Variables"
    
    cd terraform
    
    if [ ! -f "terraform.tfvars" ]; then
        print_warning "Creating terraform.tfvars from example"
        cp terraform.tfvars.example terraform.tfvars
        
        # Update with AWS Account ID
        if command -v sed &> /dev/null; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/<AWS_ACCOUNT_ID>/${AWS_ACCOUNT_ID}/g" terraform.tfvars
            else
                sed -i "s/<AWS_ACCOUNT_ID>/${AWS_ACCOUNT_ID}/g" terraform.tfvars
            fi
        fi
        
        print_warning "Please edit terraform.tfvars with your configuration:"
        echo "  - Update email addresses for alarms"
        echo "  - Update callback URLs if needed"
        echo "  - Review resource sizing (for cost optimization)"
        
        read -p "Press Enter when ready to continue..."
    else
        print_success "terraform.tfvars already exists"
    fi
    
    cd ..
}

initialize_terraform() {
    print_header "Initializing Terraform"
    
    cd terraform
    
    terraform init
    
    print_success "Terraform initialized"
    
    cd ..
}

plan_terraform() {
    print_header "Running Terraform Plan"
    
    cd terraform
    
    terraform plan -out=tfplan
    
    print_success "Terraform plan created"
    
    echo ""
    read -p "Review the plan above. Apply? (yes/no): " apply_choice
    
    cd ..
    
    if [ "$apply_choice" != "yes" ]; then
        print_warning "Skipping Terraform apply"
        return 1
    fi
    
    return 0
}

apply_terraform() {
    print_header "Applying Terraform Configuration"
    
    cd terraform
    
    terraform apply tfplan
    
    print_success "Terraform applied successfully!"
    
    # Save outputs
    terraform output > ../terraform-outputs.txt
    
    print_success "Outputs saved to terraform-outputs.txt"
    
    cd ..
}

configure_kubectl() {
    print_header "Configuring kubectl for EKS"
    
    CLUSTER_NAME=$(grep 'eks_cluster_name' terraform-outputs.txt | awk '{print $3}' | tr -d '"')
    
    if [ -z "$CLUSTER_NAME" ]; then
        print_error "Could not find cluster name in outputs"
        return 1
    fi
    
    aws eks update-kubeconfig --region us-east-1 --name "$CLUSTER_NAME"
    
    print_success "kubectl configured for cluster: $CLUSTER_NAME"
    
    # Verify connection
    kubectl cluster-info
    kubectl get nodes
}

deploy_kubernetes_resources() {
    print_header "Deploying Kubernetes Resources with Helm"
    
    print_warning "Validating Helm chart..."
    helm lint helm/max-weather/
    
    print_warning "Installing Max Weather application with Helm on Staging..."

    helm upgrade --install max-weather-staging ./helm/max-weather \
        --namespace weather-staging \
        --values ./helm/max-weather/values-staging.yaml \
        --create-namespace \
        --atomic \
        --timeout 10m \
        --wait

    print_warning "Installing Max Weather application with Helm on Production..."
    helm upgrade --install max-weather-production ./helm/max-weather \
        --namespace weather-production \
        --values ./helm/max-weather/values-production.yaml \
        --create-namespace \
        --atomic \
        --timeout 10m \
        --wait
    
    print_success "Helm chart deployed successfully!"
    
    echo ""
    echo "Helm release status:"
    helm status max-weather
    
    echo ""
    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=max-weather --timeout=5m || true
    
    print_success "All pods are ready!"
}

build_and_push_image() {
    print_header "Building and Pushing Docker Image"
    
    ECR_URL=$(grep 'ecr_repository_urls' terraform-outputs.txt | grep 'weather-api' | awk '{print $3}' | tr -d '",')
    
    if [ -z "$ECR_URL" ]; then
        print_error "Could not find ECR URL in outputs"
        return 1
    fi
    
    print_warning "Building Docker image..."
    cd application/weather-api
    docker build -t weather-api:latest .
    cd ../..
    
    print_warning "Tagging image for ECR..."
    docker tag weather-api:latest "${ECR_URL}:latest"
    
    print_warning "Logging in to ECR..."
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "$ECR_URL"
    
    print_warning "Pushing image to ECR..."
    docker push "${ECR_URL}:latest"
    
    print_success "Image pushed to ECR!"
    
    # Update deployment via Helm
    print_warning "Updating Helm release with new image on Staging..."
    helm upgrade max-weather-staging ./helm/max-weather \
        --namespace weather-staging \
        --values ./helm/max-weather/values-staging.yaml \
        --set image.tag=latest \
        --atomic \
        --timeout 5m
    print_warning "Updating Helm release with new image on Production..."
    helm upgrade max-weather-production ./helm/max-weather \
        --namespace weather-production \
        --values ./helm/max-weather/values-production.yaml \
        --set image.tag=latest \
        --atomic \
        --timeout 5m
    
    kubectl rollout status deployment/max-weather
    
    print_success "Deployment updated!"
}

print_summary() {
    print_header "Setup Complete!"
    
    echo -e "${GREEN}Your Max Weather platform is now deployed!${NC}\n"
    
    echo "Next steps:"
    echo "1. Check Helm deployment:"
    echo "   helm list -A"
    echo ""
    echo "2. Get the NLB DNS name:"
    echo "   kubectl get svc -n ingress-nginx ingress-nginx-controller"
    echo ""
    echo "3. Update API Gateway VPC Link with NLB ARN"
    echo ""
    echo "4. Create test users in Cognito"
    echo ""
    echo "5. Test the API with Postman collection"
    echo ""
    echo "6. View logs in CloudWatch:"
    DASHBOARD_URL=$(grep 'cloudwatch_dashboard_url' terraform-outputs.txt | awk -F'"' '{print $2}')
    echo "   ${DASHBOARD_URL}"
    echo ""
    echo "For detailed deployment information, see terraform-outputs.txt"
    echo ""
    print_success "Happy coding! 🚀"
}

# Main execution
main() {
    print_header "Max Weather Platform Setup"
    
    check_prerequisites
    configure_aws
    create_terraform_backend
    setup_terraform_vars
    initialize_terraform
    
    if plan_terraform; then
        apply_terraform
        configure_kubectl
        deploy_kubernetes_resources
        
        read -p "Build and push Docker image now? (yes/no): " build_choice
        if [ "$build_choice" == "yes" ]; then
            build_and_push_image
        fi
        
        print_summary
    else
        print_warning "Setup interrupted. You can run this script again to continue."
    fi
}

# Run main function
main
