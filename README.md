# Max Weather - Weather Forecasting Platform

> Production-ready, highly available weather API on AWS with Kubernetes

## 📚 Documentation

**All documentation is now consolidated in the `docs/` folder:**

### Quick Start
- **[docs/complete_guide.md](docs/complete_guide.md)** ⭐ **START HERE** - Complete implementation guide
  - Includes: Getting Started, Implementation Notes, Deployment Guide, and Project Summary

### Component Guides
- **[docs/api_gateway_setup.md](docs/api_gateway_setup.md)** - Step-by-step API Gateway setup
- **[docs/lambda.md](docs/lambda.md)** - Lambda authorizer deployment
- **[docs/architecture.md](docs/architecture.md)** - Detailed architecture diagrams
- **[docs/postman.md](docs/postman.md)** - API testing with Postman

## 🎯 Quick Reference

### Implementation Requirements
1. ✅ **Public API Integration** - OpenWeatherMap API (`application/weather-api/app.py`)
2. ✅ **Lambda Authorizer** - Custom JWT validation (`lambda/authorizer/`)
3. ✅ **Proxy API Gateway** - Single `ANY /{proxy+}` resource
4. ✅ **API Authorization** - Bearer token authentication required
5. ✅ **High Availability** - Multi-AZ, auto-scaling, fault-tolerant

### Architecture Highlights

```
Client (Bearer Token)
  ↓
API Gateway (Proxy)
  ↓
Lambda Authorizer (JWT Validation)
  ↓
VPC Link → NLB → Nginx Ingress
  ↓
Weather API Pods (1-5 replicas)
  ↓
OpenWeatherMap Public API
```

### Key Technologies
- **AWS**: EKS, Lambda, API Gateway, VPC, CloudWatch, ECR
- **Kubernetes**: 1.31, Multi-AZ deployment, HPA, Ingress
- **IaC**: Terraform (modularized)
- **Security**: Lambda Authorizer, JWT, IRSA
- **External API**: OpenWeatherMap
- **CI/CD**: Jenkins
- **Monitoring**: CloudWatch, Fluent Bit

## 🚀 Quick Start

```bash
# 1. Deploy Lambda Authorizer
cd lambda/authorizer
./deploy.sh

# 2. Deploy Infrastructure
cd terraform
terraform init
terraform apply

# 3. Deploy Application with Helm
cd helm
helm install max-weather ./max-weather \
  --namespace weather-production \
  --values ./max-weather/values-production.yaml

# 4. Create API Gateway
# Follow: docs/api_gateway_setup.md

# 5. Test
python lambda/authorizer/lambda_function.py  # Generate token
curl -H "Authorization: Bearer <token>" \
  https://your-api.com/prod/current?location=London
```

## 📁 Repository Structure

```
script-clone/
├── docs/                           # 📚 All documentation
│   ├── complete_guide.md          # ⭐ Complete guide (start here)
│   ├── api_gateway_setup.md
│   ├── lambda.md
│   ├── architecture.md
│   └── postman.md
│
├── terraform/                      # Infrastructure as Code
│   ├── main.tf
│   ├── modules/
│   │   ├── vpc/
│   │   ├── eks/
│   │   ├── ecr/
│   │   ├── cloudwatch/
│   │   ├── iam/
│   │   ├── cognito/ (optional)
│   │   └── api-gateway/ (optional)
│
├── helm/
│   └── max-weather/               # Helm chart (v1.0.0)
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-staging.yaml
│       ├── values-production.yaml
│       └── templates/             # 20 K8s templates
│
├── lambda/
│   └── authorizer/                # Custom Lambda Authorizer
│       ├── lambda_function.py
│       ├── deploy.sh
│       └── requirements.txt
│
├── application/
│   └── weather-api/               # Weather API (OpenWeatherMap)
│       ├── app.py
│       ├── Dockerfile
│       └── requirements.txt
│
├── jenkins/
│   └── Jenkinsfile                # CI/CD pipeline
│
├── postman/
│   └── max-weather-api.postman_collection.json
│
└── scripts/
    ├── setup.sh                   # Automated setup
    └── deploy.sh                  # Deployment script
```

## ✅ Deliverables

| Component | Status | Location |
|-----------|--------|----------|
| Architecture Diagram | ✅ | `docs/architecture.md` |
| Terraform (Modularized) | ✅ | `terraform/modules/` |
| Helm Chart | ✅ | `helm/max-weather/` |
| Jenkins Pipeline | ✅ | `jenkins/Jenkinsfile` (Helm deployment) |
| API Gateway | ✅ | `docs/api_gateway_setup.md` |
| Lambda Authorizer | ✅ | `lambda/authorizer/` |
| Postman Collection | ✅ | `postman/` |
| Public API Integration | ✅ | `application/weather-api/app.py` |
| Documentation | ✅ | `docs/` |

## 🔐 API Endpoints

All endpoints require `Authorization: Bearer <token>` header (except `/health`).

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | API information |
| `/health` | GET | Health check (no auth) |
| `/current?location={city}` | GET | Current weather |
| `/forecast?location={city}&days={1-7}` | GET | Weather forecast |
| `/cities` | GET | Supported cities |

## 💰 Estimated Cost

| Service | Monthly Cost |
|---------|--------------|
| EKS Control Plane | $73 |
| EC2 (3x t3.medium) | ~$90 |
| NAT Gateways (3) | ~$100 |
| NLB | ~$20 |
| API Gateway | ~$3.50 |
| Lambda | <$1 |
| CloudWatch | ~$10 |
| ECR | ~$5 |
| **Total** | **~$302** |

## 📞 Support

For issues or questions:
1. Check `docs/complete_guide.md` for detailed documentation
2. Review troubleshooting sections in component guides
3. Check CloudWatch logs

## 🏆 Project Status

- **Completion**: ✅ 90%
- **Requirements Met**: ✅ 5/5
- **Assessment Ready**: ✅ Yes
- **Documentation**: ✅ Complete

---

**Project**: Max Weather Platform  
**Version**: 1.0.0  
**Last Updated**: December 2, 2025  
**Develop by**: Kwang Le

**For complete documentation, see**: [`docs/complete_guide.md`](docs/complete_guide.md)
