# EKS Authentication Guide: aws-auth ConfigMap

This guide explains how EKS authentication works and how to properly configure the aws-auth ConfigMap to allow different AWS IAM entities to access your cluster.

## How EKS Authentication Works

Amazon EKS uses a special ConfigMap called `aws-auth` in the `kube-system` namespace to map AWS IAM users and roles to Kubernetes RBAC groups and users. This is how the system allows AWS IAM entities to authenticate to the Kubernetes API server.

### Authentication Flow

1. A user or service (like GitHub Actions) authenticates to AWS using their IAM credentials
2. They request a token for EKS access using `aws eks get-token`
3. The token is presented to the EKS API server
4. EKS validates the token with AWS IAM
5. EKS looks up the IAM entity in the aws-auth ConfigMap
6. If a mapping exists, the entity is given the Kubernetes identity specified in the mapping
7. Kubernetes RBAC then determines what actions the identity can perform

## aws-auth ConfigMap Structure

The aws-auth ConfigMap has this basic structure:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME
      username: USERNAME
      groups:
        - GROUP1
        - GROUP2
  mapUsers: |
    - userarn: arn:aws:iam::ACCOUNT_ID:user/USER_NAME
      username: USERNAME
      groups:
        - GROUP1
        - GROUP2
```

There are two main sections:

- `mapRoles`: Maps IAM roles to Kubernetes identities
- `mapUsers`: Maps IAM users to Kubernetes identities

## Common Groups

These are common Kubernetes groups you might map to:

- `system:masters`: Full administrative access to the cluster (equivalent to `cluster-admin` role)
- `system:nodes`: Required for worker nodes to join the cluster
- `system:bootstrappers`: Required for worker nodes during the bootstrap process
- Custom groups: You can create your own groups with custom RBAC roles

## Updating the aws-auth ConfigMap

### Using kubectl

```bash
# Get the current ConfigMap
kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth.yaml

# Edit the file
# ... edit aws-auth.yaml ...

# Apply the updated ConfigMap
kubectl apply -f aws-auth.yaml
```

### Using eksctl (recommended for initial setup)

```bash
# Add a role
eksctl create iamidentitymapping \
  --cluster CLUSTER_NAME \
  --region REGION \
  --arn arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME \
  --username ROLE_NAME \
  --group system:masters
```

## Required Mappings

### Node Groups

Every EKS node group must have its IAM role mapped in the ConfigMap. This is usually done automatically by EKS/eksctl, but if you delete or corrupt the ConfigMap, you'll need to add these back.

Example node mapping:
```yaml
- rolearn: arn:aws:iam::ACCOUNT_ID:role/NODE_ROLE_NAME
  username: system:node:{{EC2PrivateDNSName}}
  groups:
    - system:bootstrappers
    - system:nodes
```

### CI/CD Systems

For GitHub Actions or other CI/CD systems to access EKS, add their assumed IAM role:

```yaml
- rolearn: arn:aws:iam::ACCOUNT_ID:role/github-actions-role
  username: github-actions
  groups:
    - system:masters  # Or more restricted group as needed
```

## Troubleshooting

### Common Errors

1. **"The server has asked for the client to provide credentials"**: This usually means the IAM entity (role/user) is not properly mapped in the aws-auth ConfigMap.

2. **"User is not authorized to perform actions"**: The IAM entity is mapped, but not to groups with sufficient permissions.

### Verification

1. Check if your role is in the ConfigMap:
   ```bash
   kubectl get configmap aws-auth -n kube-system -o yaml | grep YOUR_ROLE_ARN
   ```

2. Test authorization for a specific user:
   ```bash
   kubectl auth can-i get pods --as=USERNAME
   ```

3. Check AWS authentication:
   ```bash
   aws sts get-caller-identity
   ```

## Scripts in This Repository

Here's a few scripts to help manage the aws-auth ConfigMap:

- `apply-aws-auth.sh`: Complete replacement of the aws-auth ConfigMap
- `fix-aws-auth-simple.sh`: Patches the existing ConfigMap
- `eks-auth-diagnostic.sh`: Diagnoses authentication issues

## References

- [AWS Documentation: Managing users or IAM roles for your cluster](https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html)
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/security/docs/iam/#kubernetes-rbac-authorization)
- [eksctl Documentation](https://eksctl.io/usage/iam-identity-mappings/) 