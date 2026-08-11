include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

terraform {
  # Double slash // defines the module path, ?ref=main defines the branch
  source = "git::https://github.com/taha-khalid/Terraform_Modules.git//ec2?ref=main"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    public_subnet_id = "subnet-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]

}

dependency "security_groups" {
  config_path = "../security_groups"
  mock_outputs = {
    master_sg_id = "sg-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  instance_count     = include.env.locals.master_instance_count
  instance_name      = "master"
  instance_type      = "t3.medium"
  key_name           = "k8s-bare-metal"
  subnet_id          = dependency.vpc.outputs.public_subnet_id
  security_group_ids = [dependency.security_groups.outputs.master_sg_id]
  ami_id             = "ami-0b6d9d3d33ba97d99" # Ubuntu 26.04 LTS x86_64
  disk_size          = 20
}