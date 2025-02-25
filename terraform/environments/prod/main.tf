# GitHub OIDC Provider and IAM Role
# Use data source for existing OIDC provider instead of trying to create it
data "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

# Original resource kept but commented out for reference
# resource "aws_iam_openid_connect_provider" "github_actions" {
#   url             = "https://token.actions.githubusercontent.com"
#   client_id_list  = ["sts.amazonaws.com"]
#   thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
#   # Handle existing resources and prevent destroy
#   lifecycle {
#     prevent_destroy = true
#     ignore_changes = [
#       thumbprint_list,
#     ]
#     # Add this to handle the case where the resource already exists
#     create_before_destroy = true
#   }
# }

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github_actions.arn]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}

# Use data source for existing IAM role
data "aws_iam_role" "github_actions" {
  name = "github-actions-role"
}

# Original resource kept but commented out for reference
# resource "aws_iam_role" "github_actions" {
#   name               = "github-actions-role"
#   assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
#   # Prevent destroy of this resource when Terraform runs
#   lifecycle {
#     prevent_destroy = true
#   }
# }

# Use data source for existing IAM policy
data "aws_iam_policy" "github_actions" {
  name = "github-actions-policy"
}

# Original resource kept but commented out for reference
# resource "aws_iam_policy" "github_actions" {
#   name = "github-actions-policy"
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "eks:*",
#           "ecr:*",
#           "iam:*",
#           "vpc:*",
#           "ec2:*",
#           "kms:*",
#           "logs:*",
#           "cloudwatch:*"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
#   # Handle existing resources and prevent destroy
#   lifecycle {
#     prevent_destroy = true
#     ignore_changes = [
#       policy,
#     ]
#     # Add this to handle the case where the resource already exists
#     create_before_destroy = true
#   }
# }

# Use data source for existing EKS cluster
data "aws_eks_cluster" "portfolio_cluster" {
  name = "portfolio-cluster"
}

# VPC Configuration
# Comment out VPC module that creates new VPC
# module "vpc" {
#   source  = "terraform-aws-modules/vpc/aws"
#   version = "~> 5.0"
#
#   name = "portfolio-vpc"
#   cidr = "10.0.0.0/16"
#
#   azs             = ["us-west-1a", "us-west-1b"]
#   private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
#   public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
#
#   enable_nat_gateway     = true
#   single_nat_gateway     = true
#   one_nat_gateway_per_az = false
#
#   enable_dns_hostnames = true
#   enable_dns_support   = true
#
#   public_subnet_tags = {
#     "kubernetes.io/role/elb" = 1
#   }
#
#   private_subnet_tags = {
#     "kubernetes.io/role/internal-elb" = 1
#   }
#
#   tags = {
#     Environment = "prod"
#     Terraform   = "true"
#   }
# }

# Use data sources for existing VPC and subnets
data "aws_vpc" "existing" {
  # Instead of filtering by name tag, just get the first available VPC
  # This will typically return the default VPC if it exists
  default = true
}

# Fallback data source if no default VPC exists
data "aws_vpcs" "all" {
  # Only used if the default VPC doesn't exist
}

locals {
  # Use the first VPC from the list if the default VPC doesn't exist
  vpc_id = try(data.aws_vpc.existing.id, tolist(data.aws_vpcs.all.ids)[0])
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  # Remove the tag filter since the subnets might not have these tags
  # filter {
  #   name   = "tag:Name"
  #   values = ["*private*"] # Adjust this filter as needed for your subnet naming
  # }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  # Remove the tag filter since the subnets might not have these tags
  # filter {
  #   name   = "tag:Name"
  #   values = ["*public*"] # Adjust this filter as needed for your subnet naming
  # }
}

# Fetch individual subnet details if needed (commented out since we don't filter by tags anymore)
# data "aws_subnet" "private" {
#   for_each = toset(data.aws_subnets.private.ids)
#   id       = each.value
# }

# data "aws_subnet" "public" {
#   for_each = toset(data.aws_subnets.public.ids)
#   id       = each.value
# }

# EKS Configuration - use only for references, don't create the cluster
locals {
  eks_cluster_name = "portfolio-cluster"
}

# EKS Module - commented out to prevent trying to create an already existing cluster
# module "eks" {
#   source  = "terraform-aws-modules/eks/aws"
#   version = "~> 19.0"
#
#   cluster_name    = local.eks_cluster_name
#   cluster_version = "1.28"
#
#   cluster_endpoint_public_access = true
#
#   vpc_id     = local.vpc_id
#   subnet_ids = data.aws_subnets.private.ids
# }

# Existing outputs
output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions"
  value       = data.aws_iam_role.github_actions.arn
}

# Additional outputs
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = data.aws_eks_cluster.portfolio_cluster.endpoint
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = data.aws_eks_cluster.portfolio_cluster.name
}

output "vpc_id" {
  description = "VPC ID"
  value       = local.vpc_id
}

output "subnets" {
  description = "List of subnet IDs"
  value = {
    private = data.aws_subnets.private.ids
    public  = data.aws_subnets.public.ids
  }
}