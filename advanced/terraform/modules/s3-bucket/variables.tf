
variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "environment" {
  description = "Environment where the bucket is used"
  type        = string
}

variable "cost_center" {
  description = "Cost center for this bucket"
  type        = string
}

variable "owner" {
  description = "Owner of this bucket"
  type        = string
}
