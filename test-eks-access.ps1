# PowerShell script to test EKS cluster access

# Set variables
$AWS_REGION = "us-west-1"
$EKS_CLUSTER_NAME = "portfolio-cluster"

Write-Host "Testing EKS access for cluster $EKS_CLUSTER_NAME in region $AWS_REGION"

# Verify AWS credentials
Write-Host "`n=== Verifying AWS identity ===" -ForegroundColor Cyan
aws sts get-caller-identity

# Update kubeconfig
Write-Host "`n=== Updating kubeconfig ===" -ForegroundColor Cyan
aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $AWS_REGION

# Get EKS cluster info
Write-Host "`n=== Getting EKS cluster info ===" -ForegroundColor Cyan
aws eks describe-cluster --name $EKS_CLUSTER_NAME --region $AWS_REGION --query "cluster.status"

# Test kubectl
Write-Host "`n=== Testing kubectl access ===" -ForegroundColor Cyan
try {
    kubectl get nodes
} catch {
    Write-Host "Failed to get nodes - authentication issue" -ForegroundColor Red
}

# Check aws-auth ConfigMap
Write-Host "`n=== Checking aws-auth ConfigMap ===" -ForegroundColor Cyan
try {
    kubectl get configmap aws-auth -n kube-system -o yaml
} catch {
    Write-Host "Failed to get aws-auth ConfigMap" -ForegroundColor Red
}

# Check IAM roles in aws-auth ConfigMap
Write-Host "`n=== IAM roles in aws-auth ConfigMap ===" -ForegroundColor Cyan
try {
    $configMap = kubectl get configmap aws-auth -n kube-system -o yaml
    if ($configMap -match "mapRoles") {
        $configMap | Select-String -Pattern "mapRoles" -Context 0,5
    } else {
        Write-Host "No mapRoles found in aws-auth ConfigMap" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Failed to get mapRoles from aws-auth ConfigMap" -ForegroundColor Red
}

# Show all services
Write-Host "`n=== Kubernetes services ===" -ForegroundColor Cyan
try {
    kubectl get svc --all-namespaces
} catch {
    Write-Host "Failed to get services" -ForegroundColor Red
}

Write-Host "`n=== Test complete ===" -ForegroundColor Green 