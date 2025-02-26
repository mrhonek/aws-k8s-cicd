# EKS Authentication Diagnostic Script

# 1. Check AWS CLI configuration
Write-Host "=== AWS CLI Configuration ===" -ForegroundColor Cyan
aws sts get-caller-identity

# 2. Check EKS access
Write-Host "`n=== EKS Access ===" -ForegroundColor Cyan
aws eks list-clusters
$CLUSTER_NAME = "portfolio-cluster"
$REGION = "us-west-1"

# 3. Check authentication mode
Write-Host "`n=== EKS Cluster Authentication Mode ===" -ForegroundColor Cyan
$clusterInfo = aws eks describe-cluster --name $CLUSTER_NAME --region $REGION | ConvertFrom-Json
Write-Host "Authentication Mode:" $clusterInfo.cluster.accessConfig.authenticationMode

# 4. Verify the GitHub Actions role
Write-Host "`n=== GitHub Actions Role ===" -ForegroundColor Cyan
$GITHUB_ROLE = "arn:aws:iam::537124942860:role/github-actions-role"
Write-Host "Checking IAM role: $GITHUB_ROLE"
try {
    aws iam get-role --role-name github-actions-role | ConvertFrom-Json | Select-Object -ExpandProperty Role | Select-Object RoleName, Arn, CreateDate
} catch {
    Write-Host "Error getting role details: $_" -ForegroundColor Red
}

# 5. Check AWS Auth ConfigMap
Write-Host "`n=== AWS Auth ConfigMap ===" -ForegroundColor Cyan
Write-Host "Setting up kubeconfig..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION
Write-Host "Getting aws-auth ConfigMap..."
try {
    kubectl get configmap aws-auth -n kube-system -o yaml
} catch {
    Write-Host "Error getting aws-auth ConfigMap: $_" -ForegroundColor Red
}

# 6. Check access review
Write-Host "`n=== Kubernetes Access Review ===" -ForegroundColor Cyan
Write-Host "This simulates the access the GitHub Actions role would have:"
try {
    kubectl auth can-i list pods --as=github-actions
    kubectl auth can-i create deployments --as=github-actions
} catch {
    Write-Host "Error checking access: $_" -ForegroundColor Red
}

# 7. Diagnostic summary
Write-Host "`n=== Diagnostic Summary ===" -ForegroundColor Green
Write-Host "Based on this diagnostic check:"
Write-Host "1. If the authentication mode is 'API' or 'API_AND_CONFIG_MAP', update both the aws-auth ConfigMap and IAM"
Write-Host "2. If the GitHub Actions role doesn't exist or has incorrect permissions, create/update it"
Write-Host "3. Make sure the aws-auth ConfigMap contains the correct role ARN mapping"
Write-Host ""
Write-Host "AWS CLI command to update the EKS cluster config (if authentication mode is 'CONFIG_MAP'):"
Write-Host "aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION"
Write-Host ""
Write-Host "If using IRSA (IAM Roles for Service Accounts):"
Write-Host "Check the OIDC provider and service account configuration in your EKS cluster" 