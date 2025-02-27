# AWS EKS CI/CD Pipeline with Terraform, Helm, and GitHub Actions

A complete CI/CD pipeline for deploying applications to Amazon EKS using Terraform, GitHub Actions, Helm, and ECR.

## Overview

This project demonstrates a modern CI/CD workflow for Kubernetes applications:

1. **Infrastructure as Code**: Use Terraform to provision and manage AWS infrastructure
2. **Build & Push**: Containerize your application and push to Amazon ECR
3. **Deploy**: Use Helm to deploy to Amazon EKS
4. **Notify**: Send deployment status notifications to Slack

## Prerequisites

- AWS Account with permissions for:
  - ECR (Elastic Container Registry)
  - EKS (Elastic Kubernetes Service)
  - IAM (Identity and Access Management)
  - VPC and associated networking services
- GitHub repository
- Slack workspace (for notifications)
- Terraform CLI (for infrastructure management)

## Setup Instructions

### 1. Infrastructure as Code with Terraform

The project uses Terraform to provision and manage the following AWS resources:
- VPC with public and private subnets
- EKS cluster and node groups
- IAM roles and policies
- Security groups
- ECR repository

#### Terraform Directory Structure
```
environments/
└── prod/
    ├── main.tf        # Main configuration file
    ├── variables.tf   # Input variables
    ├── outputs.tf     # Output values
    └── terraform.tfvars # Variable values for production
```

#### Deploying Infrastructure
```bash
# Initialize Terraform
cd environments/prod
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply
```

#### Destroying Infrastructure
When you're done with the project, you can tear down all resources:
```bash
terraform destroy
```

#### Benefits of Infrastructure as Code
- **Reproducibility**: The entire infrastructure can be recreated consistently
- **Version Control**: Infrastructure changes are tracked in Git alongside application code
- **Documentation**: The Terraform code serves as living documentation of your infrastructure
- **Modularity**: Components can be reused across different environments
- **Testing**: Infrastructure can be validated before deployment
- **Automation**: Reduces manual configuration steps and human error

### 2. AWS Infrastructure

#### IAM Role for GitHub Actions

Create an IAM role with the following permissions:
- `AmazonECR-FullAccess`
- `AmazonEKSClusterPolicy`

Configure OIDC provider for GitHub Actions:
```bash
# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list <thumbprint>

# Create role trust policy
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<GITHUB_USERNAME>/<REPO_NAME>:*"
        }
      }
    }
  ]
}
EOF

# Create the IAM role
aws iam create-role --role-name github-actions-role --assume-role-policy-document file://trust-policy.json
```

#### EKS Cluster Configuration

Ensure your EKS cluster's aws-auth ConfigMap includes the GitHub Actions role:

```bash
# Update aws-auth ConfigMap
cat > aws-auth-complete.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::<ACCOUNT_ID>:role/github-actions-role
      username: github-actions
      groups:
        - system:masters
    - rolearn: <NODE_ROLE_ARN>
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOF

kubectl apply -f aws-auth-complete.yaml
```

### 2. GitHub Repository Setup

#### Secrets Configuration

Add the following secrets to your GitHub repository:
- `SLACK_WEBHOOK_URL`: Your Slack webhook URL for notifications

### 3. Application Configuration

#### Helm Chart Structure

The Helm chart should be structured as follows:
```
kubernetes/
└── helm/
    └── app/
        ├── Chart.yaml
        ├── values.yaml
        ├── templates/
        │   ├── deployment.yaml
        │   ├── service.yaml
        │   └── ...
        └── ...
```

#### Customize values.yaml

Update `values.yaml` with your application's configuration:
```yaml
image:
  repository: <ECR_URI>
  tag: latest
  pullPolicy: Always

service:
  type: ClusterIP
  port: 80

# Add other configuration as needed
```

## Usage

### Workflow Triggers

The CI/CD pipeline can be triggered in two ways:
1. **Automatic**: Push to the `main` branch
2. **Manual**: Use the "Run workflow" button in GitHub Actions UI

### Monitoring Deployments

1. **GitHub Actions**: Check the workflow runs in the "Actions" tab
2. **Slack Notifications**: Receive real-time updates in your configured Slack channel
3. **Kubernetes Dashboard**: View deployed resources in your cluster

## Troubleshooting

### Common Issues

#### Terraform State Issues

If you encounter Terraform state corruption or conflicts:
1. Check the state file for corruption: `terraform state list`
2. Refresh the state: `terraform refresh`
3. If necessary, use state manipulation commands: `terraform state mv`, `terraform state rm`

#### Authentication Errors

If you see "the server has asked for the client to provide credentials":
1. Verify the IAM role has correct permissions
2. Check the aws-auth ConfigMap in your EKS cluster
3. Run the `docs/apply-aws-auth.sh` script to fix the ConfigMap

#### Image Pull Failures

If pods can't pull the image:
1. Verify ECR permissions
2. Check the image URL and tag in the Helm values
3. Ensure the GitHub Actions role has ECR access

## Scripts

This repository includes helpful scripts in the `docs/` directory:

- `apply-aws-auth.sh`: Fixes the aws-auth ConfigMap for GitHub Actions authentication
- `eks-auth-diagnostic.sh`: Diagnoses EKS authentication issues
- `fix-aws-auth-simple.sh`: Simple script to patch the aws-auth ConfigMap
- `tf-deploy.sh`: Helper script for Terraform deployment workflow

## Project Components

### Infrastructure (Terraform)
- VPC with public and private subnets across multiple availability zones
- EKS cluster with managed node groups
- IAM roles with least privilege permissions
- Security groups for controlled network access
- ECR repository for container images

### CI/CD (GitHub Actions)
- Automated workflows for build, test, and deploy
- Secure authentication with AWS using OIDC
- Integration with Slack for notifications

### Deployment (Helm)
- Kubernetes manifests templated for flexibility
- Release management with versioning
- Configuration values separated from templates

## License

[MIT License](LICENSE) 