"""
Lambda Authorizer for API Gateway
Validates Bearer tokens and generates IAM policies
"""
import json
import os
import jwt
from jwt import PyJWKClient
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Configuration - can be environment variables
COGNITO_USER_POOL_ID = os.environ.get('COGNITO_USER_POOL_ID', '')
COGNITO_REGION = os.environ.get('COGNITO_REGION', 'us-east-1')
COGNITO_APP_CLIENT_ID = os.environ.get('COGNITO_APP_CLIENT_ID', '')

# Alternatively, use custom JWT issuer for simple token validation
JWT_SECRET = os.environ.get('JWT_SECRET', 'your-secret-key-change-in-production')
TOKEN_ISSUER = os.environ.get('TOKEN_ISSUER', 'max-weather-api')

def lambda_handler(event, context):
    """
    Lambda authorizer handler
    
    Args:
        event: API Gateway authorizer event
        context: Lambda context
        
    Returns:
        IAM policy document allowing/denying access
    """
    logger.info(f"Authorizer invoked with event: {json.dumps(event)}")
    
    try:
        # Extract token from Authorization header
        token = extract_token(event)
        
        if not token:
            logger.error("No token found in request")
            raise Exception('Unauthorized')
        
        # Validate token
        claims = validate_token(token)
        
        # Extract principal ID (user identifier)
        principal_id = claims.get('sub') or claims.get('username') or 'user'
        
        # Generate IAM policy
        policy = generate_policy(
            principal_id=principal_id,
            effect='Allow',
            resource=event['methodArn'],
            context=claims
        )
        
        logger.info(f"Authorization successful for principal: {principal_id}")
        return policy
        
    except Exception as e:
        logger.error(f"Authorization failed: {str(e)}")
        # Return Deny policy
        raise Exception('Unauthorized')


def extract_token(event):
    """
    Extract bearer token from Authorization header
    
    Args:
        event: API Gateway event
        
    Returns:
        Token string or None
    """
    auth_header = event.get('authorizationToken', '')
    
    # Handle 'Bearer <token>' format
    if auth_header.startswith('Bearer '):
        return auth_header[7:]
    
    # Handle token without 'Bearer ' prefix
    return auth_header if auth_header else None


def validate_token(token):
    """
    Validate JWT token
    
    Args:
        token: JWT token string
        
    Returns:
        Token claims (dict)
        
    Raises:
        Exception if token is invalid
    """
    try:
        # Option 1: Validate against Cognito (if using Cognito)
        if COGNITO_USER_POOL_ID:
            return validate_cognito_token(token)
        
        # Option 2: Simple JWT validation with shared secret
        return validate_simple_jwt(token)
        
    except jwt.ExpiredSignatureError:
        logger.error("Token has expired")
        raise Exception('Token expired')
    except jwt.InvalidTokenError as e:
        logger.error(f"Invalid token: {str(e)}")
        raise Exception('Invalid token')
    except Exception as e:
        logger.error(f"Token validation error: {str(e)}")
        raise


def validate_cognito_token(token):
    """
    Validate JWT token from AWS Cognito
    
    Args:
        token: JWT token string
        
    Returns:
        Token claims (dict)
    """
    # Get JWKS URL for Cognito
    jwks_url = f'https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}/.well-known/jwks.json'
    
    # Get signing key
    jwks_client = PyJWKClient(jwks_url)
    signing_key = jwks_client.get_signing_key_from_jwt(token)
    
    # Decode and validate token
    claims = jwt.decode(
        token,
        signing_key.key,
        algorithms=["RS256"],
        audience=COGNITO_APP_CLIENT_ID,
        options={"verify_exp": True}
    )
    
    logger.info(f"Cognito token validated for user: {claims.get('username')}")
    return claims


def validate_simple_jwt(token):
    """
    Validate JWT token with shared secret (for testing/simple auth)
    
    Args:
        token: JWT token string
        
    Returns:
        Token claims (dict)
    """
    # Decode and validate token
    claims = jwt.decode(
        token,
        JWT_SECRET,
        algorithms=["HS256"],
        issuer=TOKEN_ISSUER,
        options={"verify_exp": True}
    )
    
    logger.info(f"Simple JWT validated for user: {claims.get('sub')}")
    return claims


def generate_policy(principal_id, effect, resource, context=None):
    """
    Generate IAM policy document
    
    Args:
        principal_id: User identifier
        effect: 'Allow' or 'Deny'
        resource: ARN of the API Gateway method
        context: Additional context to pass to backend (optional)
        
    Returns:
        IAM policy document
    """
    # Build the policy document
    auth_response = {
        'principalId': principal_id
    }
    
    if effect and resource:
        policy_document = {
            'Version': '2012-10-17',
            'Statement': [
                {
                    'Action': 'execute-api:Invoke',
                    'Effect': effect,
                    'Resource': resource
                }
            ]
        }
        auth_response['policyDocument'] = policy_document
    
    # Add context if provided (will be available in backend as $context.authorizer)
    if context:
        # Context values must be strings, numbers, or booleans
        auth_response['context'] = {
            'userId': str(context.get('sub', '')),
            'username': str(context.get('username', '')),
            'email': str(context.get('email', '')),
            'scope': str(context.get('scope', ''))
        }
    
    return auth_response


def generate_token(user_id, username, email='', expires_in=3600):
    """
    Helper function to generate JWT tokens for testing
    (This would typically be in a separate authentication service)
    
    Args:
        user_id: User ID
        username: Username
        email: Email address
        expires_in: Token expiration in seconds
        
    Returns:
        JWT token string
    """
    import time
    
    payload = {
        'sub': user_id,
        'username': username,
        'email': email,
        'iss': TOKEN_ISSUER,
        'iat': int(time.time()),
        'exp': int(time.time()) + expires_in
    }
    
    token = jwt.encode(payload, JWT_SECRET, algorithm='HS256')
    return token


# For testing locally
if __name__ == '__main__':
    # Generate a test token
    test_token = generate_token(
        user_id='test-user-123',
        username='testuser',
        email='test@example.com'
    )
    print(f"Test Token: {test_token}")
    
    # Test the authorizer
    test_event = {
        'type': 'TOKEN',
        'authorizationToken': f'Bearer {test_token}',
        'methodArn': 'arn:aws:execute-api:us-east-1:123456789012:abcdef123/prod/GET/current'
    }
    
    result = lambda_handler(test_event, None)
    print(f"\nAuthorizer Result: {json.dumps(result, indent=2)}")
