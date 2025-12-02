# Max Weather Platform - Infrastructure Architecture

## Executive Summary

This document describes the complete infrastructure architecture for the Max Weather platform, a highly available, production-ready weather forecasting system built on AWS using Kubernetes (Amazon EKS) and deployed with Helm charts for production-grade package management.

## Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                                  Internet                                       │
└────────────────────────────────┬───────────────────────────────────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │    Route 53 (DNS)       │
                    │  weather.kwangle.weather │
                    └────────────┬────────────┘
                                 │
┌────────────────────────────────────────────────────────────────────────────────┐
│                              AWS Region (us-east-1)                             │
│                                                                                 │
│  ┌──────────────────────────────────────────────────────────────────────────┐ │
│  │                          AWS API Gateway                                  │ │
│  │  ┌────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐  │ │
│  │  │  REST API      │  │ OAuth2 Authorizer│  │  CloudWatch Logs       │  │ │
│  │  │  /forecast     │──│  (AWS Cognito)   │  │  API Access Logs       │  │ │
│  │  │  /current      │  │  - User Pool     │  │  Metrics               │  │ │
│  │  └────────┬───────┘  └──────────────────┘  └─────────────────────────┘  │ │
│  └───────────┼──────────────────────────────────────────────────────────────┘ │
│              │                                                                  │
│  ┌───────────▼──────────────────────────────────────────────────────────────┐ │
│  │                          VPC Link                                         │ │
│  │  (Private Integration between API Gateway and VPC)                       │ │
│  └───────────┬──────────────────────────────────────────────────────────────┘ │
│              │                                                                  │
│  ┌───────────▼──────────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                                      │ │
│  │                                                                            │ │
│  │  ┌─────────────────────────────────────────────────────────────────────┐ │ │
│  │  │                    Public Subnets                                    │ │ │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │ │ │
│  │  │  │ AZ-1a        │  │ AZ-1b        │  │ AZ-1c        │             │ │ │
│  │  │  │ 10.0.1.0/24  │  │ 10.0.2.0/24  │  │ 10.0.3.0/24  │             │ │ │
│  │  │  │              │  │              │  │              │             │ │ │
│  │  │  │  ┌────────┐  │  │  ┌────────┐  │  │  ┌────────┐  │             │ │ │
│  │  │  │  │ NAT-GW │  │  │  │ NAT-GW │  │  │  │ NAT-GW │  │             │ │ │
│  │  │  │  └────────┘  │  │  └────────┘  │  │  └────────┘  │             │ │ │
│  │  │  │              │  │              │  │              │             │ │ │
│  │  │  │  ┌────────┐  │  │  ┌────────┐  │  │  ┌────────┐  │             │ │ │
│  │  │  │  │Internet│  │  │  │Internet│  │  │  │Internet│  │             │ │ │
│  │  │  │  │Gateway │  │  │  │Gateway │  │  │  │Gateway │  │             │ │ │
│  │  │  │  └────────┘  │  │  └────────┘  │  │  └────────┘  │             │ │ │
│  │  │  └──────────────┘  └──────────────┘  └──────────────┘             │ │ │
│  │  │         │                  │                  │                     │ │ │
│  │  │  ┌──────▼──────────────────▼──────────────────▼──────┐             │ │ │
│  │  │  │       Network Load Balancer (NLB)                 │             │ │ │
│  │  │  │       Internal, Multi-AZ                          │             │ │ │
│  │  │  └──────┬────────────────────────────────────────────┘             │ │ │
│  │  └─────────┼────────────────────────────────────────────────────────┘ │ │
│  │            │                                                            │ │
│  │  ┌─────────▼────────────────────────────────────────────────────────┐ │ │
│  │  │                    Private Subnets                                │ │ │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │ │ │
│  │  │  │ AZ-1a        │  │ AZ-1b        │  │ AZ-1c        │           │ │ │
│  │  │  │ 10.0.11.0/24 │  │ 10.0.12.0/24 │  │ 10.0.13.0/24 │           │ │ │
│  │  │  │              │  │              │  │              │           │ │ │
│  │  │  │ ┌──────────────────────────────────────────────┐ │           │ │ │
│  │  │  │ │        Amazon EKS Cluster                    │ │           │ │ │
│  │  │  │ │        (max-weather-production-cluster)                 │ │           │ │ │
│  │  │  │ │                                              │ │           │ │ │
│  │  │  │ │  ┌────────────────────────────────────────┐ │ │           │ │ │
│  │  │  │ │  │   Control Plane (Managed by AWS)       │ │ │           │ │ │
│  │  │  │ │  │   - API Server                          │ │ │           │ │ │
│  │  │  │ │  │   - etcd                                │ │ │           │ │ │
│  │  │  │ │  │   - Controller Manager                  │ │ │           │ │ │
│  │  │  │ │  └────────────────────────────────────────┘ │ │           │ │ │
│  │  │  │ │                                              │ │           │ │ │
│  │  │  │ │  ┌────────────────────────────────────────┐ │ │           │ │ │
│  │  │  │ │  │   Data Plane (Worker Nodes)            │ │ │           │ │ │
│  │  │  │ │  │                                        │ │ │           │ │ │
│  │  │  │ │  │  ┌──────────────────────────────────┐ │ │ │           │ │ │
│  │  │  │ │  │  │  Nginx Ingress Controller        │ │ │ │           │ │ │
│  │  │  │ │  │  │  - DaemonSet/Deployment          │ │ │ │           │ │ │
│  │  │  │ │  │  │  - Service Type: LoadBalancer    │ │ │ │           │ │ │
│  │  │  │ │  │  └─────────────┬────────────────────┘ │ │ │           │ │ │
│  │  │  │ │  │                │                       │ │ │           │ │ │
│  │  │  │ │  │  ┌─────────────▼────────────────────┐ │ │ │           │ │ │
│  │  │  │ │  │  │  Weather API Deployment          │ │ │ │           │ │ │
│  │  │  │ │  │  │                                  │ │ │ │           │ │ │
│  │  │  │ │  │  │  ┌────┐ ┌────┐ ┌────┐ ┌────┐   │ │ │ │           │ │ │
│  │  │  │ │  │  │  │Pod1│ │Pod2│ │Pod3│ │...│    │ │ │ │           │ │ │
│  │  │  │ │  │  │  └────┘ └────┘ └────┘ └────┘   │ │ │ │           │ │ │
│  │  │  │ │  │  │  Min: 3, Max: 10 replicas      │ │ │ │           │ │ │
│  │  │  │ │  │  └──────────────────────────────┘ │ │ │           │ │ │
│  │  │  │ │  │                                    │ │ │           │ │ │
│  │  │  │ │  │  ┌──────────────────────────────┐ │ │ │           │ │ │
│  │  │  │ │  │  │  Horizontal Pod Autoscaler   │ │ │ │           │ │ │
│  │  │  │ │  │  │  - CPU Target: 70%           │ │ │ │           │ │ │
│  │  │  │ │  │  │  - Memory Target: 80%        │ │ │ │           │ │ │
│  │  │  │ │  │  └──────────────────────────────┘ │ │ │           │ │ │
│  │  │  │ │  │                                    │ │ │           │ │ │
│  │  │  │ │  │  ┌──────────────────────────────┐ │ │ │           │ │ │
│  │  │  │ │  │  │  Fluent Bit DaemonSet        │ │ │ │           │ │ │
│  │  │  │ │  │  │  - Collect container logs    │ │ │ │           │ │ │
│  │  │  │ │  │  │  - Forward to CloudWatch     │ │ │ │           │ │ │
│  │  │  │ │  │  └──────────────────────────────┘ │ │ │           │ │ │
│  │  │  │ │  │                                    │ │ │           │ │ │
│  │  │  │ │  │  ┌──────────────────────────────┐ │ │ │           │ │ │
│  │  │  │ │  │  │  Managed Node Group          │ │ │ │           │ │ │
│  │  │  │ │  │  │  - Instance Type: t3.medium  │ │ │ │           │ │ │
│  │  │  │ │  │  │  - Min: 2, Max: 6 nodes      │ │ │ │           │ │ │
│  │  │  │ │  │  │  - Auto Scaling Group        │ │ │ │           │ │ │
│  │  │  │ │  │  └──────────────────────────────┘ │ │ │           │ │ │
│  │  │  │ │  └────────────────────────────────────┘ │ │           │ │ │
│  │  │  │ └──────────────────────────────────────────┘ │           │ │ │
│  │  │  └──────────────┘  └──────────────┘  └──────────────┘       │ │ │
│  │  └───────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                    AWS CloudWatch                               │ │
│  │  ┌──────────────────┐  ┌──────────────────┐                    │ │
│  │  │  Log Groups      │  │  Metrics         │                    │ │
│  │  │  - Application   │  │  - CPU Usage     │                    │ │
│  │  │  - EKS Cluster   │  │  - Memory        │                    │ │
│  │  │  - API Gateway   │  │  - Request Count │                    │ │
│  │  │  - Fluent Bit    │  │  - Error Rate    │                    │ │
│  │  └──────────────────┘  └──────────────────┘                    │ │
│  │  ┌──────────────────┐  ┌──────────────────┐                    │ │
│  │  │  Alarms          │  │  Dashboards      │                    │ │
│  │  │  - High CPU      │  │  - Overview      │                    │ │
│  │  │  - High Error    │  │  - Performance   │                    │ │
│  │  │  - Pod Failures  │  │  - Logs          │                    │ │
│  │  └──────────────────┘  └──────────────────┘                    │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                Amazon ECR (Container Registry)                  │ │
│  │  ┌────────────────────────────────────────────────────────┐    │ │
│  │  │  Repository: max-weather/weather-api                    │    │ │
│  │  │  - Image Scanning: Enabled                              │    │ │
│  │  │  - Lifecycle Policy: Keep last 30 images                │    │ │
│  │  └────────────────────────────────────────────────────────┘    │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                    AWS Cognito                                  │ │
│  │  ┌────────────────────────────────────────────────────────┐    │ │
│  │  │  User Pool: max-weather-users                           │    │ │
│  │  │  - OAuth2 Flows                                         │    │ │
│  │  │  - App Client for API Gateway                           │    │ │
│  │  └────────────────────────────────────────────────────────┘    │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────┐
│                  CI/CD Pipeline (Jenkins with Helm)                    │
│                    (Can be on EC2 or external)                        │
├───────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐          │
│  │  Source  │──▶│  Build   │──▶│   Test   │──▶│  Push to │          │
│  │  (Git)   │   │  Docker  │   │   Unit   │   │   ECR    │          │
│  └──────────┘   └──────────┘   └──────────┘   └──────────┘          │
│                                                      │                 │
│                                                      ▼                 │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │                   STAGING DEPLOYMENT (Helm)                      │ │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌─────────────┐ │ │
│  │  │Helm Lint  │─▶│Helm Diff  │─▶│Helm Deploy│─▶│Smoke Tests  │ │ │
│  │  │Validate   │  │Show Changes│  │--atomic   │  │Health Check │ │ │
│  │  └───────────┘  └───────────┘  └───────────┘  └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                 │                                     │
│                                 ▼                                     │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │                    APPROVAL GATE                                 │ │
│  │  Manual approval required (24h timeout)                          │ │
│  │  Authorized approvers: admin, devops-lead                        │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                 │                                     │
│                                 ▼                                     │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │                PRODUCTION DEPLOYMENT (Helm)                      │ │
│  │  ┌───────────┐  ┌───────────┐  ┌────────────┐  ┌────────────┐ │ │
│  │  │Helm Lint  │─▶│Helm Diff  │─▶│Manual      │─▶│Helm Deploy │ │ │
│  │  │Validate   │  │Review     │  │Approval    │  │--atomic    │ │ │
│  │  └───────────┘  └───────────┘  └────────────┘  └─────┬──────┘ │ │
│  │                                                        │         │ │
│  │  ┌──────────────────┐                                 │         │ │
│  │  │ Health Checks    │◀────────────────────────────────┘         │ │
│  │  │ Verify All Pods  │                                           │ │
│  │  └──────────────────┘                                           │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                 │                                     │
│                                 ▼                                     │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │              POST-DEPLOYMENT                                     │ │
│  │  • Tag Git Release (v${BUILD_NUMBER})                           │ │
│  │  • Update Helm History                                          │ │
│  │  • Send Notifications (Email/Slack)                             │ │
│  │  • Auto-Rollback on Failure (helm rollback)                     │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                                                        │
└───────────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Network Layer

#### VPC Configuration
- **CIDR Block**: 10.0.0.0/16
- **Availability Zones**: 3 (us-east-1a, us-east-1b, us-east-1c)
- **Public Subnets**: 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24
- **Private Subnets**: 10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24

#### Internet Gateway
- Provides internet access to public subnets
- Routes public traffic to/from the internet

#### NAT Gateways
- One per AZ for high availability
- Allows private subnet resources to access the internet
- Handles outbound traffic from EKS nodes

#### Network Load Balancer (NLB)
- Type: Internal
- Distributes traffic from API Gateway to Nginx Ingress
- Health checks on target groups
- Cross-zone load balancing enabled

### 2. Compute Layer (EKS)

#### Control Plane
- Fully managed by AWS
- Multi-AZ deployment
- Automatic version updates and patching
- 99.95% SLA

#### Worker Nodes (Managed Node Group)
- **Instance Type**: t3.medium (2 vCPU, 4GB RAM)
- **Min Nodes**: 2
- **Max Nodes**: 6
- **Desired**: 3
- **AMI**: Amazon EKS optimized AMI
- **Auto Scaling**: Based on pod resource requests

#### Cluster Add-ons
- VPC CNI Plugin
- CoreDNS
- kube-proxy
- AWS EBS CSI Driver
- Cluster Autoscaler

### 3. Application Layer

#### Weather API Pods
- **Language**: Python (Flask/FastAPI)
- **Container Image**: Stored in Amazon ECR
- **Resource Requests**: 
  - CPU: 200m
  - Memory: 256Mi
- **Resource Limits**:
  - CPU: 500m
  - Memory: 512Mi
- **Replicas**: 
  - Min: 3 (HA requirement)
  - Max: 10 (peak load handling)

#### Health Checks
- **Liveness Probe**: HTTP GET /health every 10s
- **Readiness Probe**: HTTP GET /ready every 5s
- **Startup Probe**: HTTP GET /startup with 60s timeout

#### Environment Variables
- `ENVIRONMENT`: staging/production
- `LOG_LEVEL`: info/debug
- `CLOUDWATCH_LOG_GROUP`: /aws/eks/max-weather/application

### 4. Networking (Kubernetes)

#### Nginx Ingress Controller
- **Type**: Official Kubernetes Ingress-Nginx
- **Service Type**: LoadBalancer (creates NLB)
- **Replicas**: 3 (one per AZ)
- **Configuration**:
  - SSL termination
  - Request routing based on path
  - Rate limiting
  - Custom error pages

#### Kubernetes Service
- **Type**: ClusterIP
- **Port**: 80 → 8000 (container)
- **Selector**: app=weather-api

#### Ingress Rules
```yaml
Rules:
  - Host: internal.kwangle.weather
    Paths:
      - /forecast → weather-api-service:80
      - /current → weather-api-service:80
      - /health → weather-api-service:80
```

### 5. Auto Scaling

#### Horizontal Pod Autoscaler (HPA)
```yaml
Metrics:
  - CPU Utilization: Target 70%
  - Memory Utilization: Target 80%
Scale Up:
  - Threshold exceeded for 30 seconds
  - Adds 2 pods at a time (max 50% increase)
Scale Down:
  - Threshold below target for 5 minutes
  - Removes 1 pod at a time
  - Respects PodDisruptionBudget
```

#### Cluster Autoscaler
- Monitors pending pods
- Adds nodes when pods can't be scheduled
- Removes underutilized nodes after 10 minutes
- Respects node group min/max limits

#### Pod Disruption Budget
- Min Available: 2 pods
- Ensures availability during voluntary disruptions

### 6. API Management

#### AWS API Gateway
- **Type**: Regional REST API
- **Stage**: v1
- **Base Path**: /api/v1
- **Endpoints**:
  - GET /forecast?location={city}
  - GET /current?location={city}
  - POST /forecast (batch)

#### VPC Link
- Connects API Gateway to internal NLB
- Keeps traffic within AWS network
- Improves security and reduces latency

#### OAuth2 Authorization
- **Provider**: AWS Cognito
- **Grant Types**: 
  - Authorization Code
  - Client Credentials
- **Token Expiry**: 
  - Access Token: 1 hour
  - Refresh Token: 30 days
- **Scopes**:
  - read:forecast
  - write:forecast

#### Rate Limiting
- **Default**: 10,000 requests/second
- **Burst**: 5,000 requests
- **Per-client**: 100 requests/second

### 7. Observability (CloudWatch)

#### Log Groups
- `/aws/eks/max-weather/application` - Application logs
- `/aws/eks/max-weather/cluster` - EKS control plane logs
- `/aws/apigateway/max-weather` - API Gateway access logs
- `/aws/fluent-bit/max-weather` - Fluent Bit logs

#### Fluent Bit Configuration
- **DaemonSet**: Runs on every node
- **Input**: Kubernetes container logs
- **Filter**: 
  - Add Kubernetes metadata
  - Parse JSON logs
  - Add cluster/namespace/pod information
- **Output**: CloudWatch Logs

#### Custom Metrics
- Request count per endpoint
- Response time (p50, p95, p99)
- Error rate (4xx, 5xx)
- Pod CPU/Memory usage
- HPA scaling events

#### Alarms
- High error rate (> 5% for 5 minutes)
- High CPU (> 80% for 10 minutes)
- High memory (> 85% for 10 minutes)
- Pod crash loop
- Node not ready

### 8. Container Registry (ECR)

#### Repository Configuration
- **Name**: max-weather/weather-api
- **Image Scanning**: Enabled on push
- **Tag Immutability**: Enabled
- **Lifecycle Policy**:
  - Keep last 30 tagged images
  - Delete untagged images after 1 day
- **Encryption**: AES-256

### 9. CI/CD Pipeline (Jenkins with Helm)

#### Pipeline Overview

The CI/CD pipeline uses Helm for declarative, version-controlled deployments with automated validation and manual approval gates for production.

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   
│ Checkout │──▶│  Build   │──▶│   Test   │──▶│ Push ECR │   
│   Code   │   │  Docker  │   │   Unit   │   │  + Scan  │   
└──────────┘   └──────────┘   └──────────┘   └──────────┘   
                                                     │
                    ┌────────────────────────────────┘
                    ▼
         ╔══════════════════════════╗
         ║   STAGING DEPLOYMENT     ║
         ╠══════════════════════════╣
         ║ 1. Helm Lint            ║
         ║ 2. Helm Diff            ║
         ║ 3. Helm Deploy          ║
         ╚══════════════════════════╝
                    │
                    ▼
         ┌────────────────────┐
         │ Manual Approval    │
         │ (24h timeout)      │
         └────────────────────┘
                    │
                    ▼
         ╔══════════════════════════╗
         ║  PRODUCTION DEPLOYMENT   ║
         ╠══════════════════════════╣
         ║ 1. Helm Lint            ║
         ║ 2. Helm Diff            ║
         ║ 3. Manual Approval      ║ ← Review Diff
         ║ 4. Helm Deploy          ║
         ╚══════════════════════════╝
                    │
                    ▼
         ┌────────────────────┐
         │   Tag Release      │
         │   Send Notify      │
         └────────────────────┘
```

#### Pipeline Stages

**1. Checkout**
- Pull latest code from Git repository
- Verify branch and commit
- Load Jenkinsfile and Helm charts

**2. Build Docker Image**
- Build Docker image with multi-stage builds
- Tag with build number: `${BUILD_NUMBER}`
- Tag as latest: `latest`
- Include build metadata:
  - `BUILD_NUMBER=${BUILD_NUMBER}`
  - `GIT_COMMIT=${GIT_COMMIT}`
  - `BUILD_DATE=${TIMESTAMP}`

**3. Run Tests**
- Execute unit tests with pytest
- Generate code coverage report (target: >80%)
- Run linting checks (flake8, black)
- Perform security scans with Trivy
- Validate Dockerfile best practices

**4. Push to ECR**
- Authenticate to Amazon ECR
- Push tagged images to repository
- Initiate ECR vulnerability scanning
- Verify image integrity
- Update image manifest

**5. Deploy to Staging (Helm-based)**

This stage uses Helm for staging deployment:

**5a. Helm Lint**
```bash
helm lint ./helm/max-weather
```
- Validates chart syntax and structure
- Checks for deprecated APIs
- Verifies template rendering
- Ensures values schema compliance

**5b. Helm Diff**
```bash
helm diff upgrade max-weather ./helm/max-weather \
  --namespace default \
  --values ./helm/max-weather/values-staging.yaml \
  --set weatherApi.image.tag=${IMAGE_TAG} \
  --set global.aws.accountId=${AWS_ACCOUNT_ID}
```
- Shows exact changes to be applied
- Compares current vs. new state
- Highlights added/modified/deleted resources
- Enables informed deployment decisions

**5c. Helm Deploy (Staging)**
```bash
helm upgrade --install max-weather ./helm/max-weather \
  --namespace default \
  --create-namespace \
  --values ./helm/max-weather/values-staging.yaml \
  --set weatherApi.image.tag=${IMAGE_TAG} \
  --set global.aws.accountId=${AWS_ACCOUNT_ID} \
  --set global.aws.region=${AWS_REGION} \
  --wait --timeout 10m --atomic
```
- Atomic deployment (auto-rollback on failure)
- Waits for all resources to be ready
- Updates deployment with new image
- Maintains revision history

**5d. Verify Staging**
```bash
helm status max-weather -n weather-staging
kubectl get pods -l app=weather-api -n weather-staging
kubectl get hpa weather-api-hpa -n weather-staging
```

**6. Approval for Production**
- Manual approval gate
- Review staging test results
- Check monitoring dashboards
- Authorized approvers only (admin, devops-lead)
- 24-hour approval window

**7. Deploy to Production (Helm-based with Approval)**

**7a. Helm Lint (Production)**
```bash
helm lint ./helm/max-weather
```
- Re-validates chart before production
- Ensures no changes since staging

**7b. Helm Diff (Production)**
```bash
helm diff upgrade max-weather ./helm/max-weather \
  --namespace default \
  --values ./helm/max-weather/values-production.yaml \
  --set weatherApi.image.tag=${IMAGE_TAG} \
  --set global.aws.accountId=${AWS_ACCOUNT_ID}
```
- Shows production-specific changes
- Displays differences from current production state
- Critical review point before deployment

**7c. Manual Approval (Review Diff)**
- **CRITICAL STEP**: Review Helm diff output
- Verify resource changes are expected
- Check replica counts and resource limits
- Confirm image tag and version
- Approve/Reject deployment
- Authorized approvers only

**7d. Helm Deploy (Production)**
```bash
helm upgrade --install max-weather ./helm/max-weather \
  --namespace default \
  --create-namespace \
  --values ./helm/max-weather/values-production.yaml \
  --set weatherApi.image.tag=${IMAGE_TAG} \
  --set global.aws.accountId=${AWS_ACCOUNT_ID} \
  --set global.aws.region=${AWS_REGION} \
  --wait --timeout 15m --atomic
```
- Atomic deployment with longer timeout
- Automatic rollback on any failure
- Progressive rollout strategy
- Monitors pod health during rollout

**7e. Verify Production**
```bash
helm status max-weather -n weather-production
helm list -n weather-production
kubectl get pods -l app=weather-api -n weather-production
kubectl get hpa,pdb,ingress -n weather-production
```

**8. Post-Deployment**
- Tag Git commit: `v${BUILD_NUMBER}`
- Push Git tags to repository
- Generate release notes
- Update Helm release history
- Send success notifications (Email/Slack)

**9. Rollback (if failure)**

Automatic rollback on deployment failure:

```bash
helm rollback max-weather -n weather-production
```

- Helm automatically rolls back to previous revision
- Restores previous working state
- Alerts on-call engineer
- Captures failure logs
- Updates incident tracking

#### Helm Configuration

**Chart Location**: `./helm/max-weather`

**Values Files**:
- `values-staging.yaml`: Staging environment configuration
  - 2 replicas minimum
  - Debug logging
  - Lower resource limits
  - Host: `staging.kwangle.weather`
  
- `values-production.yaml`: Production environment configuration
  - 3 replicas minimum (HA)
  - Info logging
  - Production resource limits
  - Host: `api.kwangle.weather`
  - Stricter PodDisruptionBudget

**Dynamic Values** (set via `--set`):
- `weatherApi.image.tag=${BUILD_NUMBER}`
- `global.aws.accountId=${AWS_ACCOUNT_ID}`
- `global.aws.region=${AWS_REGION}`

#### Deployment Safety Features

**Helm Atomic Deployments**:
- `--atomic`: Automatic rollback if deployment fails
- `--wait`: Wait for all resources to reach ready state
- `--timeout`: Maximum time to wait before rollback

**Helm Diff**:
- Visual comparison before deployment
- Shows exact resource changes
- Prevents unexpected modifications
- Required approval after viewing diff

**Revision History**:
```bash
# View deployment history
helm history max-weather -n weather-${env}

# Rollback to specific revision
helm rollback max-weather <REVISION> -n weather-${env}
```

**Pod Disruption Budget**:
- Ensures minimum availability during updates
- Staging: minAvailable=1
- Production: minAvailable=2

**Rolling Update Strategy**:
- MaxSurge: 1 (one extra pod during update)
- MaxUnavailable: 0 (zero downtime)

#### Jenkins Pipeline Environment

**Container Images**:
- `docker:24-dind` - Docker builds
- `bitnami/kubectl:1.31` - Kubernetes operations
- `alpine/helm:3.13.0` - Helm deployments
- `amazon/aws-cli:2.13.0` - AWS operations

**Required Jenkins Credentials**:
- `aws-account-id`: AWS Account ID (Secret Text)
- `aws-credentials`: AWS Access Keys (AWS Credentials)

**Environment Variables**:
```groovy
AWS_REGION = 'us-east-1'
ECR_REPOSITORY = 'max-weather/weather-api'
HELM_RELEASE_NAME = 'max-weather'
HELM_CHART_PATH = './helm/max-weather'
EKS_CLUSTER_NAME_STAGING = 'max-weather-production-cluster'
EKS_CLUSTER_NAME_PRODUCTION = 'max-weather-production-cluster'
```

#### Key Benefits of Helm Integration

1. **Version Control**: All deployments tracked in Helm history
2. **Declarative**: Define desired state, Helm manages transitions
3. **Rollback Safety**: Easy rollback to any previous version
4. **Diff Visibility**: See changes before applying
5. **Atomic Operations**: All-or-nothing deployments
6. **Template Reusability**: Single chart for multiple environments
7. **Release Management**: Named releases with metadata
8. **Audit Trail**: Complete deployment history

### 10. Security

#### Network Security
- Private subnets for all workloads
- Security groups with minimal ingress/egress
- No public SSH access to nodes
- VPC Flow Logs enabled

#### Identity and Access Management
- **IRSA**: IAM Roles for Service Accounts
  - Fluent Bit: CloudWatch Logs write permissions
  - Cluster Autoscaler: EC2 auto-scaling permissions
  - External DNS: Route53 permissions
- **Node IAM Role**: Minimal permissions for node operation
- **Pod Security Standards**: Restricted mode

#### Secrets Management
- AWS Secrets Manager for sensitive data
- Kubernetes Secrets for non-sensitive config
- External Secrets Operator (optional)

#### Certificate Management
- AWS Certificate Manager for SSL/TLS
- Automatic renewal
- Wildcard certificates

### 11. Data Flow

#### Request Flow
1. Client sends request to `api.kwangle.weather`
2. Route 53 resolves to API Gateway
3. API Gateway validates OAuth2 token (Cognito)
4. Request forwarded to VPC Link
5. VPC Link routes to internal NLB
6. NLB distributes to Nginx Ingress Controller
7. Ingress routes to appropriate service
8. Service load balances to healthy pods
9. Pod processes request and returns response
10. Response flows back through the same path

#### Log Flow
1. Application writes logs to stdout/stderr
2. Container runtime captures logs
3. Fluent Bit reads logs from `/var/log/containers`
4. Fluent Bit enriches with Kubernetes metadata
5. Logs forwarded to CloudWatch Log Groups
6. CloudWatch Insights available for querying

### 12. Disaster Recovery

#### RTO/RPO Targets
- **RTO**: 30 minutes
- **RPO**: 5 minutes

#### Backup Strategy
- Infrastructure: Terraform state in S3 (versioned)
- Application: Container images in ECR
- Configuration: Kubernetes manifests in Git
- Data: External database backups (if applicable)

#### Recovery Procedures
1. Deploy infrastructure via Terraform
2. Configure kubectl access
3. Deploy Kubernetes resources
4. Restore application data (if needed)
5. Update DNS records
6. Verify functionality

### 13. Cost Optimization

#### Estimated Monthly Costs
- **EKS Control Plane**: $73
- **EC2 Instances (3 x t3.medium)**: ~$90
- **NAT Gateways (3)**: ~$100
- **Network Load Balancer**: ~$20
- **API Gateway**: ~$3.50 + usage
- **CloudWatch**: ~$10 + logs storage
- **ECR**: ~$5
- **Total**: ~$300-350/month (baseline)

#### Cost Saving Strategies
- Use Spot Instances for dev/staging (60-80% savings)
- Enable cluster autoscaler to scale down during off-hours
- Use S3 for archived CloudWatch logs
- Right-size instance types based on metrics

## Compliance and Best Practices

### AWS Well-Architected Framework

#### Operational Excellence
- Infrastructure as Code (Terraform)
- Automated deployments
- Comprehensive logging and monitoring
- Runbooks for common operations

#### Security
- Defense in depth (multiple security layers)
- Least privilege access
- Encryption at rest and in transit
- Regular security updates

#### Reliability
- Multi-AZ deployment
- Auto-scaling and self-healing
- Automated backups
- Tested disaster recovery

#### Performance Efficiency
- Auto-scaling based on demand
- Right-sized resources
- CloudWatch for performance monitoring
- Caching strategies (optional: ElastiCache)

#### Cost Optimization
- Pay-for-what-you-use with auto-scaling
- Spot instances for non-critical workloads
- Regular cost reviews
- Resource tagging for cost allocation

## Conclusion

This architecture provides a robust, scalable, and secure platform for the Max Weather application. It leverages AWS managed services to reduce operational overhead while maintaining full control over the application deployment through Kubernetes.

Key benefits:
- **High Availability**: Multi-AZ deployment with automatic failover
- **Scalability**: Automatic scaling at both pod and node levels
- **Security**: OAuth2 authentication, private networking, IAM integration
- **Observability**: Comprehensive logging and monitoring
- **Automation**: Full CI/CD pipeline with safety gates
- **Portability**: Infrastructure as Code for easy replication

---

**Document Version**: 1.0  
**Last Updated**: December 2, 2025  
**Author**: Kwang Le
