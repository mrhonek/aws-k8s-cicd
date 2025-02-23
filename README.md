# AWS EKS CI/CD Pipeline with Terraform and Slack Integration

This project implements a complete CI/CD pipeline using GitHub Actions, Terraform, AWS EKS, and Slack integration for managing containerized applications.

## Architecture Overview

- **CI/CD Pipeline**: GitHub Actions for automated deployments
- **Infrastructure**: AWS EKS cluster managed by Terraform
- **Containerization**: Docker with AWS ECR
- **Orchestration**: Kubernetes on EKS
- **Service Management**: Slack integration for service control

## Project Structure

```
aws-k8s-cicd/
├── .github/
│   └── workflows/        # GitHub Actions workflow definitions
├── terraform/
│   ├── modules/         # Reusable Terraform modules
│   └── environments/    # Environment-specific configurations
├── kubernetes/
│   └── helm/           # Helm charts for application deployment
├── src/
│   └── slackbot/       # Slack integration service
└── docker/             # Dockerfile and container configurations
```

## Prerequisites

- AWS Account with appropriate permissions
- GitHub account
- Slack workspace with admin access
- Terraform installed locally
- AWS CLI configured
- kubectl installed
- Helm installed

## Setup Instructions

1. **AWS Configuration**
   - Configure AWS credentials
   - Create an S3 bucket for Terraform state
   - Set up AWS ECR repository

2. **Terraform Infrastructure**
   ```bash
   cd terraform/environments/prod
   terraform init
   terraform plan
   terraform apply
   ```

3. **GitHub Actions Setup**
   - Add AWS credentials to GitHub Secrets
   - Add Slack webhook URL to GitHub Secrets
   - Configure other required environment variables

4. **Slack Integration**
   - Create a Slack app in your workspace
   - Configure bot permissions
   - Add Slack tokens to AWS Secrets Manager

## Available Slack Commands

- `/service-status`: Check the status of deployed services
- `/restart-service [service-name]`: Restart a specific service
- `/scale-service [service-name] [replicas]`: Scale service replicas

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

MIT License

## Contact

For questions and support, please open an issue in the GitHub repository. 