# Max Weather API - Postman Collection

## Overview
This Postman collection provides comprehensive testing for the Max Weather API with OAuth2 authentication using AWS Cognito.

## Setup Instructions

### 1. Import the Collection
1. Open Postman
2. Click **Import** button
3. Select `max-weather-api.postman_collection.json`
4. Click **Import**

### 2. Configure Environment Variables

Create a new environment in Postman with the following variables:

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `base_url` | API Gateway endpoint | `https://abc123.execute-api.us-east-1.amazonaws.com/v1` |
| `aws_region` | AWS region | `us-east-1` |
| `cognito_domain` | Cognito domain prefix | `max-weather-production` |
| `api_gateway_id` | API Gateway ID | `abc123xyz` |
| `cognito_client_id` | Cognito App Client ID | `1234567890abcdef` |
| `cognito_client_secret` | Cognito App Client Secret | `secret123...` |

#### Getting These Values

**API Gateway ID:**
```bash
terraform output api_gateway_id
# Or from AWS Console: API Gateway → APIs → max-weather-production-api
```

**Cognito Credentials:**
```bash
terraform output cognito_app_client_id
terraform output cognito_app_client_secret
# Or from AWS Console: Cognito → User Pools → max-weather-production-users → App clients
```

**Base URL:**
```bash
terraform output api_gateway_endpoint
```

### 3. Configure OAuth2 Authentication

#### Option 1: Collection-Level Auth (Recommended)
1. Click on the collection name
2. Go to **Authorization** tab
3. Type: Select **OAuth 2.0**
4. Configure as follows:
   - **Token Name**: Max Weather Token
   - **Grant Type**: Authorization Code
   - **Callback URL**: `https://oauth.pstmn.io/v1/callback`
   - **Auth URL**: `https://{{cognito_domain}}.auth.{{aws_region}}.amazoncognito.com/oauth2/authorize`
   - **Access Token URL**: `https://{{cognito_domain}}.auth.{{aws_region}}.amazoncognito.com/oauth2/token`
   - **Client ID**: `{{cognito_client_id}}`
   - **Client Secret**: `{{cognito_client_secret}}`
   - **Scope**: `openid email profile`
   - **Client Authentication**: Send as Basic Auth header

5. Click **Get New Access Token**
6. Sign in with Cognito credentials
7. Click **Use Token**

#### Option 2: Client Credentials Flow (For API-to-API)
Use this for machine-to-machine authentication:

```bash
curl -X POST \
  https://{{cognito_domain}}.auth.{{aws_region}}.amazoncognito.com/oauth2/token \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=client_credentials&client_id={{cognito_client_id}}&client_secret={{cognito_client_secret}}'
```

### 4. Create Test Users in Cognito

#### Via AWS CLI:
```bash
# Create a test user
aws cognito-idp admin-create-user \
  --user-pool-id <USER_POOL_ID> \
  --username testuser@example.com \
  --user-attributes Name=email,Value=testuser@example.com Name=email_verified,Value=true \
  --temporary-password TempPassword123! \
  --message-action SUPPRESS \
  --region us-east-1

# Set permanent password
aws cognito-idp admin-set-user-password \
  --user-pool-id <USER_POOL_ID> \
  --username testuser@example.com \
  --password SecurePassword123! \
  --permanent \
  --region us-east-1
```

#### Via AWS Console:
1. Go to **Cognito** → **User Pools** → `max-weather-production-users`
2. Click **Users** → **Create user**
3. Enter email and password
4. Uncheck "Send invitation"
5. Click **Create user**

## Collection Structure

### 1. Health Checks (No Auth Required)
- `GET /health` - Service health check
- `GET /ready` - Readiness probe
- `GET /` - API information

### 2. Weather Endpoints (OAuth2 Required)
- `GET /current?location={city}` - Current weather
- `GET /forecast?location={city}&days={1-14}` - Weather forecast
- `GET /cities` - List available cities

### 3. Error Handling Tests
- Missing parameters
- Invalid city names
- Invalid day ranges
- Unauthorized requests

## Running the Collection

### Individual Requests
1. Select a request from the collection
2. Ensure OAuth2 token is valid
3. Click **Send**
4. View response

### Collection Runner (All Tests)
1. Click on collection name
2. Click **Run**
3. Select requests to run
4. Configure iterations and delay
5. Click **Run Max Weather API**

### Newman (CLI)
```bash
# Install Newman
npm install -g newman

# Run collection
newman run max-weather-api.postman_collection.json \
  --environment max-weather-env.json \
  --reporters cli,html \
  --reporter-html-export newman-report.html

# Run with specific folder
newman run max-weather-api.postman_collection.json \
  --folder "Weather Endpoints (Authenticated)" \
  --environment max-weather-env.json
```

## Example Requests

### Get Current Weather
```bash
curl -X GET \
  'https://abc123.execute-api.us-east-1.amazonaws.com/v1/current?location=London' \
  -H 'Authorization: Bearer eyJraWQiOiJ...' \
  -H 'Content-Type: application/json'
```

**Response:**
```json
{
  "location": {
    "name": "London",
    "latitude": 51.5074,
    "longitude": -0.1278,
    "timezone": "Europe/London"
  },
  "current": {
    "temperature": 18.5,
    "feels_like": 17.2,
    "humidity": 65,
    "pressure": 1013,
    "wind_speed": 12.5,
    "wind_direction": "SW",
    "condition": "Partly Cloudy",
    "visibility": 10,
    "uv_index": 5
  },
  "timestamp": "2024-12-02T10:30:00Z"
}
```

### Get 5-Day Forecast
```bash
curl -X GET \
  'https://abc123.execute-api.us-east-1.amazonaws.com/v1/forecast?location=Paris&days=5' \
  -H 'Authorization: Bearer eyJraWQiOiJ...' \
  -H 'Content-Type: application/json'
```

## Available Cities
- New York
- London
- Tokyo
- Sydney
- Paris

## Common Issues & Troubleshooting

### Issue: "Unauthorized" (401)
**Solution:**
- Verify OAuth2 token is valid
- Click "Get New Access Token" in Postman
- Check Cognito client ID and secret

### Issue: "Location not found" (404)
**Solution:**
- Use one of the available cities (see list above)
- Check spelling and capitalization
- Use `GET /cities` to see valid cities

### Issue: "Invalid days parameter" (400)
**Solution:**
- Days must be between 1 and 14
- Ensure days is a number

### Issue: Token Expired
**Solution:**
- Tokens expire after 60 minutes
- Request a new token via OAuth2 flow
- Consider using refresh token

## Automated Testing

### Pre-request Scripts
Collection includes pre-request scripts to:
- Log request details
- Add timestamps
- Set dynamic variables

### Test Scripts
Collection includes test scripts to verify:
- Response time < 2000ms
- Valid JSON response
- Correct status codes
- Response schema validation

### Example Custom Test
```javascript
// Add to Tests tab of any request
pm.test("Weather data contains temperature", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData.current).to.have.property('temperature');
    pm.expect(jsonData.current.temperature).to.be.a('number');
});
```

## Environment Files

Create separate environments for different stages:

**Development Environment:**
```json
{
  "name": "Max Weather - Dev",
  "values": [
    {
      "key": "base_url",
      "value": "http://localhost:8000",
      "enabled": true
    }
  ]
}
```

**Staging Environment:**
```json
{
  "name": "Max Weather - Staging",
  "values": [
    {
      "key": "base_url",
      "value": "https://api-staging.maxweather.com/v1",
      "enabled": true
    }
  ]
}
```

**Production Environment:**
```json
{
  "name": "Max Weather - Production",
  "values": [
    {
      "key": "base_url",
      "value": "https://api.maxweather.com/v1",
      "enabled": true
    }
  ]
}
```

## CI/CD Integration

### Jenkins Integration
```groovy
stage('API Tests') {
    steps {
        sh '''
            newman run postman/max-weather-api.postman_collection.json \
                --environment postman/production-env.json \
                --reporters cli,junit \
                --reporter-junit-export newman-results.xml
        '''
        junit 'newman-results.xml'
    }
}
```

### GitHub Actions Integration
```yaml
- name: Run Postman Tests
  run: |
    npm install -g newman
    newman run postman/max-weather-api.postman_collection.json \
      --environment postman/production-env.json \
      --reporters cli,json
```

## Security Best Practices

1. **Never commit credentials** - Use environment variables
2. **Rotate secrets regularly** - Update Cognito client secrets
3. **Use HTTPS only** - Ensure all requests use HTTPS
4. **Limit token scope** - Request only necessary permissions
5. **Monitor API usage** - Check CloudWatch metrics

## Additional Resources

- [Postman OAuth2 Documentation](https://learning.postman.com/docs/sending-requests/authorization/#oauth-20)
- [AWS Cognito OAuth2 Flows](https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-authentication-flow.html)
- [Newman CLI Documentation](https://learning.postman.com/docs/running-collections/using-newman-cli/command-line-integration-with-newman/)

## Support

For issues or questions:
- Check CloudWatch logs: `/aws/eks/max-weather-production-cluster/application`
- Review API Gateway logs
- Contact DevOps team

---

**Last Updated**: December 2, 2025  
**Version**: 1.0.0
