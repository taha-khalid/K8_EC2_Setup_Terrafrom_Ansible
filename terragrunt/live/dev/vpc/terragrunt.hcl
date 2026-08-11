include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Dev environment shared variables
include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

terraform {
  # Double slash // defines the module path, ?ref=main defines the branch
  source = "git::https://github.com/taha-khalid/Terraform_Modules.git//vpc?ref=main"
}

inputs = {
  vpc_cidr           = "10.0.0.0/16"
  public_subnet_cidr = "10.0.1.0/24"
  availability_zone  = "us-east-1a"
}