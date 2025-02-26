# AWS EKS CI/CD Pipeline with Helm

A complete CI/CD pipeline for deploying applications to Amazon EKS using GitHub Actions, Helm, and ECR.

## Overview

This project demonstrates a modern CI/CD workflow for Kubernetes applications:

1. **Build & Push**: Containerize your application and push to Amazon ECR
2. **Deploy**: Use Helm to deploy to Amazon EKS
3. **Notify**: Send deployment status notifications to Slack

## Prerequisites

- AWS Account with permissions for:
  - ECR (Elastic Container Registry)
  - EKS (Elastic Kubernetes Service)
  - IAM (Identity and Access Management)
- GitHub repository
- Slack workspace (for notifications)

## Setup Instructions

### 1. AWS Infrastructure

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

## License

[MIT License](LICENSE) 