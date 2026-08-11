locals{
  aws_account_id = get_aws_account_id()
  
  state_bucket = "bare-metal-tf-bucket-${local.aws_account_id}-us-east-1-an"
  lock_table   = "bare-metal-k8-lock-table"
}
remote_state{
    backend = "s3"
    generate = {
        path = "backend.tf"
        if_exists = "overwrite"
    }
    config = {
        bucket         = "${local.state_bucket}"
        key            = "${path_relative_to_include()}/terraform.tfstate"
        region         = "us-east-1"
        encrypt        = true
        dynamodb_table = "${local.lock_table}"
    }
}

generate "provider" {
    path      = "provider.tf"
    if_exists = "overwrite"
    contents  = <<EOF
provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}
EOF
}