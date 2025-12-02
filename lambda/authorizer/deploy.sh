#!/bin/bash

# Lambda Authorizer Deployment Script
# Packages and deploys the custom Lambda authorizer to AWS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Lambda Authorizer Deployment${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Configuration
FUNCTION_NAME="${FUNCTION_NAME:-max-weather-authorizer}"
RUNTIME="${RUNTIME:-python3.11}"
HANDLER="${HANDLER:-lambda_function.lambda_handler}"
TIMEOUT="${TIMEOUT:-10}"
MEMORY="${MEMORY:-256}"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo "Install it from: https://aws.amazon.com/cli/"
    exit 1
fi

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is not installed${NC}"
    exit 1
fi

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    echo -e "${RED}Error: pip3 is not installed${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Cleaning up old build artifacts${NC}"
rm -rf package
rm -f authorizer.zip
echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

echo -e "${YELLOW}Step 2: Installing dependencies${NC}"
mkdir -p package
pip3 install -r requirements.txt -t package/ --quiet
echo -e "${GREEN}✓ Dependencies installed${NC}"
echo ""

echo -e "${YELLOW}Step 3: Packaging Lambda function${NC}"
cp lambda_function.py package/
cd package
zip -r ../authorizer.zip . > /dev/null
cd ..
echo -e "${GREEN}✓ Package created: authorizer.zip${NC}"
echo ""

# Check if IAM role exists
echo -e "${YELLOW}Step 4: Checking IAM role${NC}"
ROLE_NAME="lambda-authorizer-execution-role"

if aws iam get-role --role-name "$ROLE_NAME" &> /dev/null; then
    ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
    echo -e "${GREEN}✓ Using existing role: $ROLE_ARN${NC}"
else
    echo -e "${YELLOW}Creating IAM role for Lambda...${NC}"
    
    # Create trust policy
    cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

    # Create role
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document file://trust-policy.json \
        --description "Execution role for Max Weather Lambda Authorizer" \
        > /dev/null

    # Attach basic execution policy
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

    ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
    
    echo -e "${GREEN}✓ IAM role created: $ROLE_ARN${NC}"
    echo -e "${YELLOW}Waiting 10 seconds for IAM role to propagate...${NC}"
    sleep 10
    
    rm trust-policy.json
fi
echo ""

# Check if Lambda function exists
echo -e "${YELLOW}Step 5: Deploying Lambda function${NC}"

if aws lambda get-function --function-name "$FUNCTION_NAME" &> /dev/null; then
    echo -e "${YELLOW}Function exists. Updating code...${NC}"
    
    aws lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --zip-file fileb://authorizer.zip \
        > /dev/null
    
    echo -e "${GREEN}✓ Function code updated${NC}"
    
    # Update configuration
    aws lambda update-function-configuration \
        --function-name "$FUNCTION_NAME" \
        --runtime "$RUNTIME" \
        --handler "$HANDLER" \
        --timeout "$TIMEOUT" \
        --memory-size "$MEMORY" \
        > /dev/null
    
    echo -e "${GREEN}✓ Function configuration updated${NC}"
else
    echo -e "${YELLOW}Creating new Lambda function...${NC}"
    
    # Prompt for environment variables
    echo ""
    echo -e "${YELLOW}Configure environment variables:${NC}"
    echo -e "Leave blank to use defaults"
    echo ""
    
    read -p "JWT_SECRET (default: auto-generated): " JWT_SECRET
    if [ -z "$JWT_SECRET" ]; then
        JWT_SECRET=$(openssl rand -base64 32)
        echo -e "${GREEN}Generated JWT_SECRET: $JWT_SECRET${NC}"
    fi
    
    read -p "TOKEN_ISSUER (default: max-weather-api): " TOKEN_ISSUER
    TOKEN_ISSUER=${TOKEN_ISSUER:-max-weather-api}
    
    read -p "COGNITO_USER_POOL_ID (optional): " COGNITO_USER_POOL_ID
    read -p "COGNITO_REGION (default: $AWS_REGION): " COGNITO_REGION
    COGNITO_REGION=${COGNITO_REGION:-$AWS_REGION}
    read -p "COGNITO_APP_CLIENT_ID (optional): " COGNITO_APP_CLIENT_ID
    
    # Build environment variables JSON
    ENV_VARS="JWT_SECRET=$JWT_SECRET,TOKEN_ISSUER=$TOKEN_ISSUER"
    if [ -n "$COGNITO_USER_POOL_ID" ]; then
        ENV_VARS="$ENV_VARS,COGNITO_USER_POOL_ID=$COGNITO_USER_POOL_ID"
        ENV_VARS="$ENV_VARS,COGNITO_REGION=$COGNITO_REGION"
    fi
    if [ -n "$COGNITO_APP_CLIENT_ID" ]; then
        ENV_VARS="$ENV_VARS,COGNITO_APP_CLIENT_ID=$COGNITO_APP_CLIENT_ID"
    fi
    
    aws lambda create-function \
        --function-name "$FUNCTION_NAME" \
        --runtime "$RUNTIME" \
        --role "$ROLE_ARN" \
        --handler "$HANDLER" \
        --zip-file fileb://authorizer.zip \
        --timeout "$TIMEOUT" \
        --memory-size "$MEMORY" \
        --environment "Variables={$ENV_VARS}" \
        --description "Custom Lambda Authorizer for Max Weather API" \
        > /dev/null
    
    echo -e "${GREEN}✓ Lambda function created${NC}"
fi
echo ""

# Get function details
FUNCTION_ARN=$(aws lambda get-function --function-name "$FUNCTION_NAME" --query 'Configuration.FunctionArn' --output text)
echo -e "${GREEN}✓ Function ARN: $FUNCTION_ARN${NC}"
echo ""

# Test the function
echo -e "${YELLOW}Step 6: Testing the authorizer${NC}"
echo "Generating test token..."

# Generate test token using Python
TEST_TOKEN=$(python3 -c "
import sys
sys.path.insert(0, 'package')
from lambda_function import generate_token
token = generate_token('test-user-123', 'testuser', 'test@example.com')
print(token)
")

if [ -z "$TEST_TOKEN" ]; then
    echo -e "${RED}Failed to generate test token${NC}"
else
    echo -e "${GREEN}✓ Test token generated${NC}"
    
    # Create test event
    cat > test-event.json <<EOF
{
  "type": "TOKEN",
  "authorizationToken": "Bearer $TEST_TOKEN",
  "methodArn": "arn:aws:execute-api:$AWS_REGION:123456789012:abcdef123/prod/GET/current"
}
EOF
    
    echo "Testing Lambda function..."
    RESULT=$(aws lambda invoke \
        --function-name "$FUNCTION_NAME" \
        --payload file://test-event.json \
        --query 'StatusCode' \
        --output text \
        response.json 2>&1)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Lambda invocation successful${NC}"
        
        # Check response
        if grep -q "Allow" response.json; then
            echo -e "${GREEN}✓ Authorization test passed (Allow policy returned)${NC}"
        else
            echo -e "${YELLOW}⚠ Warning: Expected Allow policy not found in response${NC}"
            echo "Response:"
            cat response.json
        fi
    else
        echo -e "${RED}✗ Lambda invocation failed${NC}"
        echo "$RESULT"
    fi
    
    rm -f test-event.json response.json
fi
echo ""

# Cleanup
echo -e "${YELLOW}Step 7: Cleanup${NC}"
rm -rf package
rm -f authorizer.zip
echo -e "${GREEN}✓ Build artifacts cleaned up${NC}"
echo ""

# Summary
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Function Name: $FUNCTION_NAME"
echo "Function ARN:  $FUNCTION_ARN"
echo "Runtime:       $RUNTIME"
echo "Region:        $AWS_REGION"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Note the Function ARN above"
echo "2. Create API Gateway (see docs/API_GATEWAY_MANUAL_SETUP.md)"
echo "3. Attach this authorizer to your API Gateway methods"
echo "4. Test with: python3 lambda_function.py (to generate tokens)"
echo ""
echo -e "${GREEN}View logs:${NC}"
echo "aws logs tail /aws/lambda/$FUNCTION_NAME --follow"
echo ""
echo -e "${GREEN}Test token (for API testing):${NC}"
if [ -n "$TEST_TOKEN" ]; then
    echo "$TEST_TOKEN"
    echo ""
    echo "Use this token with:"
    echo "curl -H \"Authorization: Bearer $TEST_TOKEN\" https://your-api-url.com/current?location=London"
fi
echo ""
