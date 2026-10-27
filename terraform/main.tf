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
provider "aws" {
  region = var.region
}

# TODO 4: look up your own AWS account ID, so the bucket name can be unique
data "aws_caller_identity" "current" {}

# TODO 5: the S3 bucket
resource "aws_s3_bucket" "my_bucket" {
  # Example output: mohammad-test-123456789012-dev
  bucket = "mohammad-test-${data.aws_caller_identity.current.account_id}-${var.environment}"

  tags = {
    Environment = var.environment
    Owner       = "Mohammad"
  }
}


# TODO 6: turn versioning on
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.my_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# TODO 7: default encryption (AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.my_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# TODO 8: output the bucket name
output "bucket_name" {
  value = aws_s3_bucket.my_bucket.id
}

# TODO 9: output the bucket ARN
output "bucket_arn" {
  value = aws_s3_bucket.my_bucket.arn
}

