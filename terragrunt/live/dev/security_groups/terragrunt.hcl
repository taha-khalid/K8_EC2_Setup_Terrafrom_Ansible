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
  source = "git::https://github.com/taha-khalid/Terraform_Modules.git//security_groups?ref=main"
}

dependency "vpc" {
  config_path = "../vpc"
  # Mock outputs for commands run before 'apply'
  mock_outputs = {
    vpc_id = "vpc-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  vpc_id = dependency.vpc.outputs.vpc_id
}