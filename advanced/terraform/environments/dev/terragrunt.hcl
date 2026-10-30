include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules/s3-bucket"
}

inputs = {
  bucket_name = "shipfast-artifacts-dev"
  environment = "dev"
  cost_center = "development"
  owner       = "Sigma"
}
