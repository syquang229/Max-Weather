# Lambda Authorizer for API Gateway

## Overview

This Lambda function serves as a custom authorizer for API Gateway, validating Bearer tokens and generating IAM policies to allow or deny API access.

## Features

- **Token Validation**: Validates JWT tokens (supports both Cognito and custom JWT)
- **IAM Policy Generation**: Returns Allow/Deny policies based on token validation
- **Result Caching**: API Gateway caches authorizer results (configurable TTL)
- **Context Passing**: Passes user information to backend via authorizer context
- **Error Handling**: Comprehensive error handling with logging

## Authentication Methods

### Option 1: AWS Cognito (Recommended for Production)
Set environment variables:
```bash
COGNITO_USER_POOL_ID=us-east-1_xxxxxxxxx
COGNITO_REGION=us-east-1
COGNITO_APP_CLIENT_ID=xxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Option 2: Simple JWT with Shared Secret (For Testing)
Set environment variables:
```bash
JWT_SECRET=your-secret-key-change-in-production
TOKEN_ISSUER=max-weather-api
```

## Deployment

### 1. Package the Lambda Function

```bash
cd lambda/authorizer

# Create deployment package
pip install -r requirements.txt -t package/
cp lambda_function.py package/
cd package
zip -r ../lambda-authorizer.zip .
cd ..
```

### 2. Deploy to AWS Lambda

#### Using AWS CLI:
```bash
# Create Lambda function
aws lambda create-function \
  --function-name max-weather-authorizer \
  --runtime python3.11 \
  --role arn:aws:iam::YOUR_ACCOUNT_ID:role/lambda-execution-role \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://lambda-authorizer.zip \
  --timeout 10 \
  --memory-size 256 \
  --environment Variables="{JWT_SECRET=your-secret-key,TOKEN_ISSUER=max-weather-api}"
```

#### Using AWS Console:
1. Go to AWS Lambda console
2. Click "Create function"
3. Choose "Author from scratch"
4. Function name: `max-weather-authorizer`
5. Runtime: Python 3.11
6. Upload `lambda-authorizer.zip`
7. Set environment variables
8. Set timeout to 10 seconds

### 3. Attach to API Gateway

#### Using AWS Console:
1. Go to API Gateway console
2. Select your API (or create new)
3. Go to "Authorizers" section
4. Click "Create New Authorizer"
5. Settings:
   - Name: `max-weather-token-authorizer`
   - Type: `Lambda`
   - Lambda Function: `max-weather-authorizer`
   - Lambda Event Payload: `Token`
   - Token Source: `Authorization`
   - Token Validation: Leave blank
   - Authorization Caching: Enabled
   - TTL: 300 seconds
6. Click "Create"
7. Test with a token

#### Attach to API Methods:
1. Select a method (e.g., GET /current)
2. Click "Method Request"
3. Under "Authorization", select your authorizer
4. Deploy the API

## Integration with Kubernetes/Helm

When deploying the application with Helm, the Lambda authorizer integrates seamlessly:

```bash
# The Helm chart includes service account annotations for IRSA
helm install max-weather ./helm/max-weather \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=ROLE_ARN
```

## Token Format

The authorizer expects tokens in the `Authorization` header:

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Token Claims (Simple JWT)

```json
{
  "sub": "userid-229",
  "username": "kwang.le",
  "email": "syquang229@gmail.com",
  "iss": "max-weather-api",
  "iat": 1638360000,
  "exp": 1638363600
}
```

## Testing

### Generate Test Token

Run the Lambda function locally:
```bash
cd lambda/authorizer
python lambda_function.py
```

This will generate a test token and validate it.

### Test with API Gateway

```bash
# Get a token (example for simple JWT)
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Test API endpoint
curl -H "Authorization: Bearer $TOKEN" \
  https://your-api-id.execute-api.us-east-1.amazonaws.com/prod/current?location=London
```

### Test Authorizer Directly

In AWS Lambda console:
1. Go to your authorizer function
2. Click "Test"
3. Create test event:

```json
{
  "type": "TOKEN",
  "authorizationToken": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "methodArn": "arn:aws:execute-api:us-east-1:xxxxxxxx:abcdef123/prod/GET/current"
}
```

Expected response (Allow):
```json
{
  "principalId": "userid-229",
  "policyDocument": {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "execute-api:Invoke",
        "Effect": "Allow",
        "Resource": "arn:aws:execute-api:us-east-1:xxxxxxxxx:abcdef123/prod/GET/current"
      }
    ]
  },
  "context": {
    "userId": "userid-229",
    "username": "kwang.le",
    "email": "syquang229@gmail.com"
  }
}
```

## IAM Role for Lambda

The Lambda function needs an execution role with these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

If using Cognito, no additional permissions needed (public JWKS endpoint).

## Environment Variables

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `COGNITO_USER_POOL_ID` | Optional* | Cognito User Pool ID | `us-east-1_xxxxxxxx` |
| `COGNITO_REGION` | Optional* | AWS Region | `us-east-1` |
| `COGNITO_APP_CLIENT_ID` | Optional* | Cognito App Client ID | `xxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `JWT_SECRET` | Optional** | Shared secret for JWT | `my-secret-key` |
| `TOKEN_ISSUER` | Optional** | JWT issuer | `max-weather-api` |

*Required if using Cognito authentication  
**Required if using simple JWT authentication

## Caching

API Gateway caches authorizer results based on the token. Configure TTL in API Gateway:

- **TTL**: 300 seconds (5 minutes) recommended
- **Benefits**: Reduces Lambda invocations, improves latency
- **Consideration**: Changes to user permissions take up to TTL to propagate

## Security Best Practices

1. **Use HTTPS**: Always use HTTPS for API endpoints
2. **Rotate Secrets**: Regularly rotate JWT secrets
3. **Short Token Expiry**: Use short-lived tokens (1 hour recommended)
4. **Validate Claims**: Check issuer, audience, expiration
5. **Monitor Logs**: Enable CloudWatch logging for debugging
6. **Use Cognito**: Use AWS Cognito for production (better security)
7. **Environment Variables**: Store secrets in environment variables or Secrets Manager
8. **Least Privilege**: Grant minimal IAM permissions

## Troubleshooting

### "Unauthorized" Error
- Check token format (must be `Bearer <token>`)
- Verify token hasn't expired
- Check JWT secret matches
- Review CloudWatch logs

### "Internal Server Error"
- Check Lambda execution role permissions
- Review CloudWatch logs for errors
- Verify environment variables are set

### Caching Issues
- Reduce TTL for testing
- Use different tokens to bypass cache
- Disable caching temporarily

## CloudWatch Logs

View logs:
```bash
aws logs tail /aws/lambda/max-weather-authorizer --follow
```

## Generate Tokens for Testing

### Using Python Script

Create `generate_token.py`:
```python
import jwt
import time

def generate_token(user_id, username, secret='your-secret-key'):
    payload = {
        'sub': user_id,
        'username': username,
        'email': f'{username}@example.com',
        'iss': 'max-weather-api',
        'iat': int(time.time()),
        'exp': int(time.time()) + 3600  # 1 hour
    }
    return jwt.encode(payload, secret, algorithm='HS256')

token = generate_token('user-123', 'testuser')
print(f"Token: {token}")
```

Run:
```bash
pip install PyJWT
python generate_token.py
```

## Integration with Backend

The authorizer passes context to your backend. Access it in your application:

### In API Gateway Mapping Template:
```json
{
  "userId": "$context.authorizer.userId",
  "username": "$context.authorizer.username",
  "email": "$context.authorizer.email"
}
```

### In Lambda Backend (event object):
```python
user_id = event['requestContext']['authorizer']['userId']
username = event['requestContext']['authorizer']['username']
```

## Cost Optimization

- **Caching**: Enable with 300s TTL (reduces Lambda invocations by ~95%)
- **Reserved Concurrency**: Not needed (authorizer is lightweight)
- **Memory**: 256 MB sufficient (execution ~50-100ms)

**Estimated Cost**: ~$0.50/month for 1M requests (with caching)

## Migration to Cognito

To migrate from simple JWT to Cognito:

1. Create Cognito User Pool (or use existing from Terraform)
2. Update environment variables:
   ```bash
   COGNITO_USER_POOL_ID=us-east-1_xxxxxxxxx
   COGNITO_REGION=us-east-1
   COGNITO_APP_CLIENT_ID=xxxxxxxxxxxxxxxxxxxxxxxxxx
   ```
3. Remove JWT_SECRET and TOKEN_ISSUER
4. Redeploy Lambda function
5. Update clients to use Cognito tokens

## Related Documentation

- [API Gateway Lambda Authorizers](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-use-lambda-authorizer.html)
- [JWT.io](https://jwt.io/) - JWT debugging tool
- [AWS Cognito Documentation](https://docs.aws.amazon.com/cognito/)
