include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules/s3-bucket"
}

inputs = {
  bucket_name = "shipfast-artifacts-staging"
  environment = "staging"
  cost_center = "QA team"
  owner       = "Sigma"
}
