variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "aws-k8s-cicd"
} 