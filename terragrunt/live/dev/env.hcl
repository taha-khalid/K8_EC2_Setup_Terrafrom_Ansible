# Shared configuration for all modules inside the 'dev' environment

locals {
  environment           = "dev"
  aws_region            = "us-east-1"
  master_instance_count = 1
  worker_instance_count = 2
}

# Common inputs automatically merged into all child modules that inherit this file
inputs = {
  environment = local.environment
  aws_region  = local.aws_region

  tags = {
    Environment = local.environment
    ManagedBy   = "Terragrunt"
    Project     = "k8s-cluster"
  }
}