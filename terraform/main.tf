terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# TODO 1: variable "environment" (string, default "dev")
variable "environment" {
  type        = string
  default     = "dev"
  description = "The deployment environment name"
}

# TODO 2: variable "region" (default "us-east-1")
variable "region" {
  type        = string
  default     = "us-east-1"
  description = "The target AWS region for deployment"
}

# TODO 3: provider "aws" with only the region.
#         No access keys, ever -- Terraform reads the same credential
#         chain as the AWS CLI (the profile configured in A1).
provider "aws" {
  region = var.region
}

# TODO 4: look up your own AWS account ID, so the bucket name can be unique.
#         S3 bucket names are global, so the account ID is what keeps
#         "shipfast-artifacts-dev" from colliding with somebody else's.
data "aws_caller_identity" "current" {}

# TODO 5: the S3 bucket
resource "aws_s3_bucket" "artifacts" {
  bucket = "shipfast-artifacts-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "shipfast-devops"
  }
}

# TODO 6: turn versioning on for that bucket
resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

# TODO 7: default encryption (AES256) for that bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# TODO 8: output the bucket name
output "bucket_name" {
  value       = aws_s3_bucket.artifacts.id
  description = "The name of the ShipFast artifacts bucket"
}

# TODO 9: output the bucket ARN
output "bucket_arn" {
  value       = aws_s3_bucket.artifacts.arn
  description = "The ARN of the ShipFast artifacts bucket"
}
