# API Gateway Manual Setup Guide

## Overview

This guide walks you through manually creating the API Gateway using the AWS Console with a proxy integration and Lambda authorizer.

## Implementation Assumptions

1. **Backend API**: The weather application connects to OpenWeatherMap public API
2. **Authorization**: Custom Lambda Authorizer for token validation
3. **API Gateway**: Proxy implementation (ANY /{proxy+}) - sufficient for this use case
4. **Manual Creation**: API Gateway can be created via AWS Console (easier than Terraform for proxy setup)

## Prerequisites

- AWS Account with appropriate permissions
- Lambda authorizer deployed (see `lambda/authorizer/README.md`)
- EKS cluster running with weather API deployed
- Network Load Balancer (NLB) created by Nginx Ingress Controller

## Step 1: Get the NLB DNS Name

First, retrieve the NLB DNS name created by the Nginx Ingress Controller:

```bash
kubectl get service -n kube-system nginx-ingress-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Example output:
```
ab123456789.us-east-1.elb.amazonaws.com
```

## Step 2: Create VPC Link

### Via AWS Console:

1. Go to **API Gateway Console**
2. In the left sidebar, click **VPC Links**
3. Click **Create VPC Link**
4. Settings:
   - **Name**: `max-weather-vpc-link`
   - **Target NLB**: Select the NLB created by Ingress Controller
   - **Description**: `VPC Link for Max Weather API`
5. Click **Create**
6. Wait for status to become **Available** (~5 minutes)

### Via AWS CLI:

```bash
# Get NLB ARN
NLB_ARN=$(aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `nginx`)].LoadBalancerArn' \
  --output text)

# Create VPC Link
aws apigateway create-vpc-link \
  --name max-weather-vpc-link \
  --target-arns $NLB_ARN
```

## Step 3: Create REST API

### Via AWS Console:

1. Go to **API Gateway Console**
2. Click **Create API**
3. Choose **REST API** (not Private or HTTP API)
4. Click **Build**
5. Settings:
   - **Protocol**: REST
   - **Create new API**: New API
   - **API name**: `Max Weather API`
   - **Description**: `Weather forecasting service`
   - **Endpoint Type**: Regional
6. Click **Create API**

## Step 4: Create Lambda Authorizer

1. In your API, click **Authorizers** in left sidebar
2. Click **Create New Authorizer**
3. Settings:
   - **Name**: `max-weather-token-authorizer`
   - **Type**: Lambda
   - **Lambda Function**: Select `max-weather-authorizer`
   - **Lambda Event Payload**: Token
   - **Token Source**: `Authorization`
   - **Token Validation**: Leave blank
   - **Authorization Caching**: Enabled
   - **TTL**: 300 seconds
4. Click **Create**

### Test the Authorizer:

1. Click **Test** on your authorizer
2. Enter a test token in the format:
   ```
   Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```
3. Click **Test**
4. Verify you see "Allow" policy returned

## Step 5: Create Proxy Resource

### Option A: Single Proxy Resource (Recommended)

1. Click **Resources** in left sidebar
2. Select the root `/` resource
3. From **Actions** dropdown, select **Create Resource**
4. Enable **Configure as proxy resource**
5. Settings:
   - **Resource Name**: `proxy`
   - **Resource Path**: `{proxy+}`
   - **Enable API Gateway CORS**: Yes
6. Click **Create Resource**

### Option B: Individual Resources (More Control)

If you prefer explicit resources:

1. Create `/health` resource:
   - Actions → Create Resource
   - Resource Name: `health`
   - Resource Path: `/health`
   - Enable CORS: Yes

2. Create `/current` resource
3. Create `/forecast` resource
4. Create `/cities` resource

## Step 6: Configure ANY Method on Proxy

1. Select the `{proxy+}` resource
2. From **Actions** dropdown, select **Create Method**
3. Select **ANY** from the dropdown
4. Click the checkmark ✓
5. Integration settings:
   - **Integration type**: VPC Link
   - **Use Proxy Integration**: Yes (checked)
   - **Method**: ANY
   - **VPC Link**: Select `max-weather-vpc-link`
   - **Endpoint URL**: `http://{NLB_DNS}/{proxy}`
   - Replace `{NLB_DNS}` with your actual NLB DNS
6. Click **Save**

Example Endpoint URL:
```
http://ab123456789.us-east-1.elb.amazonaws.com/{proxy}
```

## Step 7: Add Authorizer to Method

### For Proxy Resource:

1. Select the **ANY** method under `/{proxy+}`
2. Click **Method Request**
3. Under **Authorization**, click the pencil icon
4. Select `max-weather-token-authorizer`
5. Click the checkmark ✓

### Exclude Health Check (Optional):

To allow `/health` without auth:

1. Create a separate `/health` resource
2. Create GET method
3. Set **Authorization** to `NONE`
4. Use VPC Link integration pointing to `http://{NLB_DNS}/health`

## Step 8: Deploy API

1. From **Actions** dropdown, select **Deploy API**
2. Settings:
   - **Deployment stage**: [New Stage]
   - **Stage name**: `prod`
   - **Description**: Production deployment
3. Click **Deploy**
4. Note the **Invoke URL**, e.g.:
   ```
   https://abc123.execute-api.us-east-1.amazonaws.com/prod
   ```

## Step 9: Configure Stage Settings

1. Click **Stages** in left sidebar
2. Select `prod` stage
3. Click **Logs/Tracing** tab
4. Enable:
   - **CloudWatch Logs**: Yes
   - **Log level**: INFO
   - **Log full requests/responses**: Yes (for debugging)
   - **Enable Detailed CloudWatch Metrics**: Yes
5. Click **Save Changes**

## Step 10: Test the API

### Without Authorization (should fail):

```bash
curl https://abc123.execute-api.us-east-1.amazonaws.com/prod/current?location=London
```

Expected response:
```json
{"message": "Unauthorized"}
```

### With Authorization:

First, generate a test token (see `lambda/authorizer/README.md`):

```bash
# Use Python to generate token
python lambda/authorizer/lambda_function.py
```

Then test with token:

```bash
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

curl -H "Authorization: Bearer $TOKEN" \
  https://abc123.execute-api.us-east-1.amazonaws.com/prod/current?location=London
```

Expected response:
```json
{
  "location": "London",
  "current": {
    "temperature": 59,
    "condition": "Rainy",
    ...
  },
  "timestamp": "2025-12-02T10:00:00",
  "source": "openweathermap"
}
```

## Step 11: Configure Custom Domain (Optional)

1. Go to **Custom Domain Names** in API Gateway
2. Click **Create**
3. Settings:
   - **Domain Name**: `api.maxweather.com`
   - **Certificate**: Select or create ACM certificate
   - **Endpoint Type**: Regional
4. Click **Create**
5. Add **API Mappings**:
   - **API**: Max Weather API
   - **Stage**: prod
   - **Path**: Leave empty or use `/v1`
6. Update Route 53:
   - Create CNAME record pointing to API Gateway domain

## Environment Variables for Application

Update Kubernetes deployment to include OpenWeatherMap API key:

```bash
kubectl create secret generic weather-api-secrets \
  --from-literal=OPENWEATHER_API_KEY=your-api-key-here

kubectl set env deployment/weather-api \
  --from=secret/weather-api-secrets
```

Or edit `kubernetes/deployment.yaml`:

```yaml
env:
- name: OPENWEATHER_API_KEY
  valueFrom:
    secretKeyRef:
      name: weather-api-secrets
      key: OPENWEATHER_API_KEY
- name: USE_MOCK_DATA
  value: "false"
```

## Testing Different Endpoints

### Get API Info:
```bash
curl -H "Authorization: Bearer $TOKEN" \
  https://abc123.execute-api.us-east-1.amazonaws.com/prod/
```

### Get Current Weather:
```bash
curl -H "Authorization: Bearer $TOKEN" \
  "https://abc123.execute-api.us-east-1.amazonaws.com/prod/current?location=Tokyo"
```

### Get Forecast:
```bash
curl -H "Authorization: Bearer $TOKEN" \
  "https://abc123.execute-api.us-east-1.amazonaws.com/prod/forecast?location=Paris&days=5"
```

### Get Available Cities:
```bash
curl -H "Authorization: Bearer $TOKEN" \
  https://abc123.execute-api.us-east-1.amazonaws.com/prod/cities
```

## Update Postman Collection

Update the Postman collection with your API Gateway URL:

1. Open Postman
2. Import `postman/max-weather-api.postman_collection.json`
3. Go to **Collection** → **Variables**
4. Update `base_url`:
   ```
   https://abc123.execute-api.us-east-1.amazonaws.com/prod
   ```
5. Update authorization to use your tokens

## Monitoring & Logging

### View CloudWatch Logs:

```bash
# API Gateway logs
aws logs tail /aws/apigateway/max-weather-api --follow

# Lambda authorizer logs
aws logs tail /aws/lambda/max-weather-authorizer --follow

# Application logs
kubectl logs -f deployment/weather-api
```

### View API Gateway Metrics:

1. Go to API Gateway Console
2. Select your API
3. Click **Dashboard**
4. View metrics:
   - API Calls
   - Latency
   - 4XX/5XX Errors
   - Cache Hits/Misses

## Troubleshooting

### "Unauthorized" Error:
- Check Lambda authorizer is attached to method
- Verify token format: `Bearer <token>`
- Check Lambda authorizer CloudWatch logs
- Test authorizer directly in console

### "Internal Server Error":
- Check VPC Link is **Available**
- Verify NLB DNS is correct
- Check security groups allow API Gateway to NLB
- Review API Gateway execution logs

### "Timeout" Error:
- Check NLB health checks are passing
- Verify pods are running: `kubectl get pods`
- Check Ingress Controller: `kubectl get ingress`
- Increase API Gateway timeout (default 29s)

### "502 Bad Gateway":
- Check NLB target health
- Verify Ingress rules are correct
- Check pod health checks
- Review application logs

## Cost Optimization

### Enable Caching:

1. Go to **Stages** → `prod`
2. Click **Settings**
3. Enable **Cache**:
   - **Cache capacity**: 0.5 GB
   - **Cache TTL**: 300 seconds
4. For each method, enable caching

### Usage Plans & API Keys:

1. Create **Usage Plan**:
   - Throttle: 10,000 requests/sec
   - Burst: 5,000 requests
   - Quota: 1,000,000 requests/month
2. Create **API Keys** for clients
3. Associate with usage plan
4. Enable **API Key Required** on methods

## Security Best Practices

1. **Use HTTPS Only**: API Gateway enforces TLS 1.2+
2. **Enable CloudWatch Logs**: For audit and debugging
3. **Use WAF**: Attach AWS WAF for DDoS protection
4. **Resource Policies**: Restrict access to specific IPs/VPCs
5. **Enable Access Logging**: Log all requests
6. **Rotate Secrets**: Regularly rotate JWT secrets
7. **Monitor Usage**: Set up CloudWatch alarms

## Alternative: Terraform Module (Optional)

The `terraform/modules/api-gateway/` module can automate this setup:

```bash
cd terraform
terraform apply -target=module.api_gateway
```

Update `terraform.tfvars`:
```hcl
api_gateway_create_manually = false
```

## Summary Checklist

- [ ] VPC Link created and available
- [ ] Lambda authorizer deployed and tested
- [ ] REST API created with proxy resource
- [ ] Authorizer attached to methods
- [ ] API deployed to prod stage
- [ ] CloudWatch logging enabled
- [ ] API tested with valid token
- [ ] Environment variables configured
- [ ] Postman collection updated
- [ ] Monitoring and alarms set up

## Next Steps

1. Update `terraform.tfvars` with API Gateway URL
2. Update DNS records (if using custom domain)
3. Configure rate limiting and usage plans
4. Set up CloudWatch alarms
5. Implement WAF rules
6. Document API for consumers

## Related Documentation

- [Lambda Authorizer Setup](../lambda/authorizer/README.md)
- [Deployment Guide](../DEPLOYMENT.md)
- [Postman Testing Guide](../postman/README.md)
- [Architecture Documentation](../architecture/architecture-diagram.md)
