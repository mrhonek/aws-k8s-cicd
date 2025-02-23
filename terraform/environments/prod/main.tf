module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = [for i in range(3) : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i in range(3) : cidrsubnet(var.vpc_cidr, 4, i + 3)]

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true
  enable_vpn_gateway     = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = var.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                   = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    for name, config in var.node_groups : name => {
      name           = name
      instance_types = config.instance_types
      min_size      = config.min_size
      max_size      = config.max_size
      desired_size  = config.desired_size

      subnet_ids = module.vpc.private_subnets
    }
  }

  tags = var.tags
}

module "ecr" {
  source = "terraform-aws-modules/ecr/aws"
  version = "~> 1.6"

  repository_name = "${var.environment}-app"
  repository_type = "private"

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = var.tags
}

# Create IAM role for Slack bot
resource "aws_iam_role" "slackbot" {
  name = "${var.environment}-slackbot-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Attach policy for EKS access
resource "aws_iam_role_policy" "slackbot_eks" {
  name = "${var.environment}-slackbot-eks-policy"
  role = aws_iam_role.slackbot.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = module.eks.cluster_arn
      }
    ]
  })
}

# Create Lambda function for Slack bot (placeholder - will be implemented later)
resource "aws_lambda_function" "slackbot" {
  filename         = "slackbot.zip"  # This will be created by CI/CD
  function_name    = "${var.environment}-slackbot"
  role            = aws_iam_role.slackbot.arn
  handler         = "index.handler"
  runtime         = "nodejs18.x"
  timeout         = 30

  environment {
    variables = {
      CLUSTER_NAME = var.cluster_name
      REGION      = var.aws_region
    }
  }

  tags = var.tags
} 