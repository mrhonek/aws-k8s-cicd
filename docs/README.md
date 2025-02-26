# EKS Authentication Utility Scripts

This directory contains utility scripts for setting up and troubleshooting AWS EKS authentication, particularly focusing on GitHub Actions integration with EKS.

## Security Notice

**IMPORTANT**: These scripts contain placeholders for sensitive information:
- `YOUR_ACCOUNT_ID` - Replace with your AWS account ID
- `YOUR_CLUSTER_NAME` - Replace with your EKS cluster name
- `YOUR_REGION` - Replace with your AWS region
- `YOUR_GITHUB_ROLE_NAME` - Replace with your GitHub Actions IAM role name
- `YOUR_NODE_ROLE_NAME` - Replace with your EKS node group role name

Never commit these scripts with actual values filled in. Use the placeholders and replace them locally as needed.

## Scripts Overview

### 1. `apply-aws-auth.sh`
- **Purpose**: Apply a complete aws-auth ConfigMap to your EKS cluster
- **Usage**: `./apply-aws-auth.sh`
- **Before running**: Edit the script and replace all placeholder values

### 2. `eks-auth-diagnostic.sh`
- **Purpose**: Diagnose EKS authentication issues, particularly for GitHub Actions
- **Usage**: `./eks-auth-diagnostic.sh`
- **Before running**: Edit the script and replace all placeholder values

### 3. `fix-aws-auth.sh`
- **Purpose**: Create or update the aws-auth ConfigMap with proper GitHub Actions role
- **Usage**: `./fix-aws-auth.sh`
- **Before running**: Edit the script and replace all placeholder values

### 4. `fix-aws-auth-simple.sh`
- **Purpose**: Simplified version of the fix script using kubectl patch
- **Usage**: `./fix-aws-auth-simple.sh`
- **Before running**: Edit the script and replace all placeholder values

### 5. `update-aws-auth.sh`
- **Purpose**: Update an existing aws-auth ConfigMap to add GitHub Actions role
- **Usage**: `./update-aws-auth.sh`
- **Before running**: Edit the script and replace all placeholder values

## Configuration Files

### `aws-auth-configmap.yaml`
- **Purpose**: Example aws-auth ConfigMap template
- **Usage**: Reference only, don't apply directly
- **Before using**: Replace all placeholder values

## How to Use These Scripts

1. Copy the script you need to use
2. Edit the script to replace all placeholder values with your actual values
3. Make the script executable: `chmod +x script-name.sh`
4. Run the script: `./script-name.sh`

## Troubleshooting Tips

If you encounter issues with EKS authentication:

1. Run the diagnostic script first: `./eks-auth-diagnostic.sh`
2. Check the aws-auth ConfigMap: `kubectl get configmap aws-auth -n kube-system -o yaml`
3. Verify that the GitHub Actions role ARN is correctly formatted
4. Ensure that the node role ARN is correctly mapped
5. If problems persist, try the fix-aws-auth.sh script

## Security Best Practices

- Don't store these scripts with actual values in version control
- Keep AWS credentials secure and use only the necessary permissions
- Consider using AWS IAM roles with temporary credentials when possible
- Use a .gitignore file to prevent accidental commits of sensitive files 