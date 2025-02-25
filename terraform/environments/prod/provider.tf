terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  # Explicitly disable EC2 Instance Metadata Service usage for credentials
  skip_metadata_api_check    = true
  skip_requesting_account_id = true
  
  # These settings help troubleshoot authentication issues
  skip_credentials_validation = true
  skip_region_validation      = true
}

