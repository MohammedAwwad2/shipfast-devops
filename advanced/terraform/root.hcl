locals {
  aws_region = "us-east-1"
  account_id = get_aws_account_id()
}

remote_state {
  backend = "s3"

  config = {
    bucket       = "shipfast-tfstate-${local.account_id}"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.aws_region
    encrypt      = true
    use_lockfile = true
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<EOF
provider "aws" {
  region = "${local.aws_region}"
}
EOF
}