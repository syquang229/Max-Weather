# Jenkins Helm Deployment Pipeline

## Overview

This Jenkins pipeline uses Helm to deploy the Max Weather application to both staging and production EKS clusters. The pipeline includes Helm linting, diff comparison, and manual approval gates for production deployments.

## Pipeline Stages

### 1. **Checkout**
- Clones the repository
- Sets up workspace

### 2. **Build Docker Image**
- Builds Docker image with build number tag
- Tags as both `BUILD_NUMBER` and `latest`

### 3. **Run Tests**
- Executes unit tests
- Runs linting checks
- Performs security scans

### 4. **Push to ECR**
- Authenticates to AWS ECR
- Pushes Docker images
- Initiates vulnerability scanning

### 5. **Deploy to Staging**
This stage includes three sub-steps:

#### 5a. Helm Lint & Validation
```bash
helm lint ./helm/max-weather
helm template max-weather ./helm/max-weather \
  --values ./helm/max-weather/values-staging.yaml \
  --set weatherApi.image.tag=${IMAGE_TAG}
```

#### 5b. Helm Diff
```bash
helm diff upgrade max-weather ./helm/max-weather \
  --namespace default \
  --values ./helm/max-weather/values-staging.yaml \
  --set weatherApi.image.tag=${IMAGE_TAG}
```

#### 5c. Helm Deploy
```bash
helm upgrade --install max-weather-production ./helm/max-weather \
  --namespace default \
  --values ./helm/max-weather/values-staging.yaml \
  --set weatherApi.image.tag=${IMAGE_TAG} \
  --wait --timeout 10m --atomic
```

### 6. **Run Smoke Tests (Staging)**
- Tests health endpoint
- Validates weather API endpoints
- Ensures deployment is functional

### 7. **Approval for Production**
- Manual approval gate
- Only authorized users can approve
- 24-hour timeout

### 8. **Deploy to Production**
This stage includes three sub-steps with manual approval:

#### 8a. Helm Lint & Validation
```bash
helm lint ./helm/max-weather
helm template max-weather ./helm/max-weather \
  --values ./helm/max-weather/values-production.yaml \
  --set weatherApi.image.tag=${IMAGE_TAG}
```

#### 8b. Helm Diff
```bash
helm diff upgrade max-weather ./helm/max-weather \
  --namespace default \
  --values ./helm/max-weather/values-production.yaml \
  --set weatherApi.image.tag=${IMAGE_TAG}
```

Shows exactly what will change in production deployment.

#### 8c. **Manual Approval Gate**
- Review Helm diff output
- Approve/Reject deployment
- Only authorized approvers

#### 8d. Helm Deploy
```bash
helm upgrade --install max-weather-production ./helm/max-weather \
  --namespace default \
  --values ./helm/max-weather/values-production.yaml \
  --set weatherApi.image.tag=${IMAGE_TAG} \
  --wait --timeout 15m --atomic
```

### 9. **Run Health Checks (Production)**
- Validates production deployment
- Checks HPA status
- Verifies all pods are healthy

### 10. **Tag Release**
- Tags Git commit with version
- Creates release tag

## Required Jenkins Plugins

1. **Kubernetes Plugin** - For Kubernetes-based agents
2. **Pipeline Plugin** - For pipeline support
3. **AWS Credentials Plugin** - For AWS authentication
4. **Email Extension Plugin** - For notifications

## Required Credentials

Configure these in Jenkins:

| Credential ID | Type | Description |
|---------------|------|-------------|
| `aws-account-id` | Secret Text | AWS Account ID |
| `aws-credentials` | AWS Credentials | AWS Access Key & Secret |

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `AWS_REGION` | AWS region | `us-east-1` |
| `ECR_REPOSITORY` | ECR repository name | `max-weather/weather-api` |
| `EKS_CLUSTER_NAME_STAGING` | Staging cluster | `max-weather-staging-cluster` |
| `EKS_CLUSTER_NAME_PRODUCTION` | Production cluster | `max-weather-cluster` |
| `HELM_RELEASE_NAME` | Helm release name | `max-weather` |

## Helm Values Files

### values-staging.yaml
- 2 replicas minimum
- Debug logging enabled
- Lower resource limits
- Autoscaling: 2-5 replicas
- Host: `staging.kwangle.weather`

### values-production.yaml
- 3 replicas minimum (HA)
- Info logging
- Production resource limits
- Autoscaling: 3-10 replicas
- Host: `api.kwangle.weather`
- Stricter PDB (minAvailable: 2)

## Key Features

### ✅ Helm Lint
- Validates chart syntax
- Checks for common issues
- Runs before every deployment

### ✅ Helm Diff
- Shows exact changes before deployment
- Prevents unexpected changes
- Enables informed approval decisions

### ✅ Manual Approval
- Production deployment requires manual approval
- Review diff output before approving
- Only authorized users can approve

### ✅ Atomic Deployments
- `--atomic` flag ensures rollback on failure
- `--wait` ensures all resources are ready
- Automatic rollback on any error

### ✅ Automatic Rollback
- If deployment fails, Helm automatically rolls back
- Post-failure hook also attempts rollback
- Ensures system stability

## Usage

### Trigger Pipeline

**Option 1: Automatic (Git Push)**
```bash
git push origin main
```

**Option 2: Manual (Jenkins UI)**
1. Navigate to Jenkins job
2. Click "Build Now"
3. Monitor pipeline progress

### Monitor Deployment

```bash
# Check Helm release status
helm status max-weather -n weather-${env}

# Check pod status
kubectl get pods -l app=weather-api -n weather-${env}

# View Helm history
helm history max-weather -n weather-${env}

# Check HPA
kubectl get hpa weather-api-hpa -n weather-${env}
```

### Rollback Production

**Via Helm:**
```bash
# List release history
helm history max-weather -n weather-${env}

# Rollback to previous version
helm rollback max-weather -n weather-${env}

# Rollback to specific revision
helm rollback max-weather 3 -n weather-${env}
```

**Via Jenkins:**
The pipeline automatically rolls back on failure in the `post` section.

## Approval Process

### Staging Deployment
1. Automatic after tests pass
2. No manual approval required
3. Helm lint → Helm diff → Deploy

### Production Deployment
1. **First Approval**: Proceed to production after staging success
2. **Helm Lint**: Validates production chart
3. **Helm Diff**: Shows changes
4. **Second Approval**: Review diff and approve deployment
5. **Deploy**: Executes Helm upgrade

## Notifications

### Success
- ✅ Email notification
- Release version
- Build URL
- Environment details

### Failure
- ❌ Email notification
- Error details
- Build logs link
- Automatic rollback status

## Troubleshooting

### Helm Diff Plugin Issues
If `helm diff` fails:
```bash
# Install plugin manually
helm plugin install https://github.com/databus23/helm-diff
```

### Image Tag Issues
Ensure the image tag matches the build number:
```bash
# Check ECR for image
aws ecr describe-images \
  --repository-name max-weather/weather-api \
  --region us-east-1
```

### Deployment Stuck
If deployment is stuck in waiting:
```bash
# Check pod status
kubectl describe pod <pod-name> -n weather-${env}

# Check events
kubectl get events -n weather-${env} --sort-by='.lastTimestamp'
```

### Rollback Failed
If automatic rollback fails:
```bash
# Manual rollback
helm rollback max-weather -n weather-${env}

# Or use previous image
helm upgrade max-weather ./helm/max-weather \
  --set weatherApi.image.tag=<PREVIOUS_TAG> \
  --reuse-values
```

## Best Practices

1. **Always Review Diff**: Check the Helm diff output before approving production
2. **Test in Staging**: Ensure staging deployment is successful and tested
3. **Gradual Rollout**: Use Helm's `--wait` and `--atomic` flags
4. **Monitor After Deploy**: Watch pods and logs after deployment
5. **Keep Values Synchronized**: Ensure staging and production values are consistent

## Security Considerations

1. **IAM Roles**: Use IRSA (IAM Roles for Service Accounts)
2. **Secrets Management**: Store sensitive data in AWS Secrets Manager
3. **Image Scanning**: ECR vulnerability scanning enabled
4. **Network Policies**: Configure appropriate ingress rules
5. **RBAC**: Limit Jenkins service account permissions

## Next Steps

1. Configure Jenkins credentials
2. Update IAM role ARNs in values files
3. Set up email notifications
4. Configure Slack webhooks (optional)
5. Test pipeline in staging environment
6. Review and approve production deployment

## References

- [Helm Documentation](https://helm.sh/docs/)
- [Helm Diff Plugin](https://github.com/databus23/helm-diff)
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Max Weather Helm Chart](../helm/max-weather/README.md)
