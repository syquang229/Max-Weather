# Max Weather Helm Chart

A Helm chart for deploying the Max Weather platform on Kubernetes (Amazon EKS).

## Overview

This Helm chart packages all components of the Max Weather platform:
- **Weather API Application**: Flask-based weather forecasting service
- **Nginx Ingress Controller**: Load balancing and routing
- **Fluent Bit**: CloudWatch logging integration
- **Horizontal Pod Autoscaler**: Auto-scaling based on CPU/Memory
- **Pod Disruption Budget**: High availability guarantees

## Prerequisites

- Kubernetes 1.31
- Helm 3.8+
- Amazon EKS cluster
- AWS IAM roles for service accounts (IRSA) configured
- ECR repository with weather-api image

## Installation

### 1. Configure Your Values

Use prod.yaml values file:

Edit `prod.yaml` and set:
- `global.aws.accountId`: Your AWS Account ID
- `global.aws.region`: Your AWS region
- `weatherApi.serviceAccount.annotations.eks.amazonaws.com/role-arn`: IAM role ARN for weather API
- `fluentBit.serviceAccount.annotations.eks.amazonaws.com/role-arn`: IAM role ARN for Fluent Bit

### 2. Install the Chart

```bash
# Install with custom values
helm install max-weather-production ./helm/max-weather -f prod.yaml

### 3. Verify Installation

```bash
# Check all resources
helm status max-weather-production

# Check pods
kubectl get pods -n weather-${env}
kubectl get pods -n ingress-nginx
kubectl get pods -n monitoring

# Check ingress
kubectl get ingress -n weather-${env}

# Check HPA
kubectl get hpa -n weather-${env}
```

## Configuration

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.aws.accountId` | AWS Account ID | `"xxxxxxxxx"` |
| `global.aws.region` | AWS Region | `us-east-1` |
| `global.cluster.name` | EKS cluster name | `max-weather-production-cluster` |
| `weatherApi.enabled` | Enable weather API deployment | `true` |
| `weatherApi.replicaCount` | Number of replicas | `2` |
| `weatherApi.image.tag` | Docker image tag | `latest` |
| `autoscaling.enabled` | Enable HPA | `true` |
| `autoscaling.minReplicas` | Minimum replicas | `2` |
| `autoscaling.maxReplicas` | Maximum replicas | `5` |
| `ingressController.enabled` | Enable Nginx Ingress Controller | `true` |
| `fluentBit.enabled` | Enable Fluent Bit logging | `true` |
| `ingress.enabled` | Create Ingress resource | `true` |


## Upgrading

```bash
# Upgrade with new values
helm upgrade max-weather ./helm/max-weather -f values-production.yaml

# Upgrade with new image tag
helm upgrade max-weather ./helm/max-weather \
  --set weatherApi.image.tag=v1.0.1 \
  --reuse-values
```

## Uninstalling

```bash
# Uninstall the release
helm uninstall max-weather-production

# Clean up CRDs and namespaces if needed
kubectl delete namespace ingress-nginx
kubectl delete namespace amazon-cloudwatch
```

## Common Operations

### View Rendered Templates

```bash
# See what Kubernetes manifests will be created
helm template max-weather ./helm/max-weather -f values-production.yaml

# Debug template rendering
helm install max-weather-production ./helm/max-weather --dry-run --debug
```

## Architecture

The chart deploys the following Kubernetes resources:

### Weather Namespace
- Deployment: weather-api (3 replicas)
- Service: weather-api-service (ClusterIP)
- ServiceAccount: weather-api
- Ingress: weather-api-ingress
- HorizontalPodAutoscaler: weather-api-hpa
- PodDisruptionBudget: weather-api-pdb

### Ingress-Nginx Namespace
- Deployment: ingress-nginx-controller (3 replicas)
- Service: ingress-nginx-controller (LoadBalancer/NLB)
- ConfigMap: ingress-nginx-controller
- RBAC: ClusterRole, ClusterRoleBinding, Role, RoleBinding
- IngressClass: nginx

### Monitoring Namespace
- DaemonSet: fluent-bit (runs on all nodes)
- ServiceAccount: fluent-bit
- ConfigMap: fluent-bit-config
- RBAC: ClusterRole, ClusterRoleBinding

## Troubleshooting

### Check Helm Release Status

```bash
helm list
helm status max-weather
helm get values max-weather
```

### View Logs

```bash
# Weather API logs
kubectl logs -l app=weather-api -n weather-${env}

# Ingress Controller logs
kubectl logs -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx

# Fluent Bit logs
kubectl logs -l k8s-app=fluent-bit -n monitoring
```

### Common Issues

**Issue**: Pods not starting
```bash
# Check pod events
kubectl describe pod <pod-name> -n weather-${env}

# Check image pull permissions
kubectl get serviceaccount weather-api -n weather-${env} -o yaml
```

**Issue**: Ingress not working
```bash
# Check ingress status
kubectl describe ingress weather-api-ingress -n weather-${env}

# Check ingress controller
kubectl get svc -n ingress-nginx
kubectl logs -l app.kubernetes.io/component=controller -n ingress-nginx
```

**Issue**: Autoscaling not working
```bash
# Check HPA status
kubectl get hpa -n weather-${env}
kubectl describe hpa weather-api-hpa -n weather-${env}

# Check metrics server
kubectl top nodes
kubectl top pods -n weather-${env}
```

## Development

### Chart Structure

```
helm/max-weather/
├── Chart.yaml                      # Chart metadata
├── values.yaml                     # Default values
├── prod.yaml                       # Production values
├── templates/
│   ├── _helpers.tpl                # Template helpers
│   ├── deployment.yaml             # Weather API deployment
│   ├── service.yaml                # Weather API service
│   ├── serviceaccount.yaml         # Weather API service account
│   ├── ingress.yaml                # Ingress resource
│   ├── hpa.yaml                    # Horizontal Pod Autoscaler
│   ├── pdb.yaml                    # Pod Disruption Budget
│   ├── ingress-controller/         # Nginx Ingress Controller
│   │   ├── namespace.yaml
│   │   ├── configmap.yaml
│   │   ├── rbac.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── fluent-bit/                 # Fluent Bit DaemonSet
│       ├── namespace.yaml
│       ├── rbac.yaml
│       ├── configmap.yaml
│       └── daemonset.yaml
└── README.md                       # This file
```

### Testing

```bash
# Lint the chart
helm lint ./helm/max-weather

# Validate templates
helm template max-weather ./helm/max-weather --debug

# Dry run installation
helm install max-weather-production ./helm/max-weather --dry-run --debug
```

## Support

For issues and questions:
- GitHub: https://github.com/syquang229/Max-Weather
- Documentation: See `/docs` folder in repository

## License

See repository LICENSE file.
