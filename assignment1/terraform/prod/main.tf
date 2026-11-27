terraform {
  required_version = "~> 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }

  backend "s3" {
    bucket       = "acs730-tfstate-973858201364"
    key          = "assignment1/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Course      = "ACS730"
      Assignment  = "assignment1"
      Environment = "prod"
    }
  }
}

module "app" {
  source = "../modules/app"

  environment   = "prod"
  owner         = "azaia2"
  instance_type = "t3.small"
  vpc_cidr      = "10.30.0.0/16"

  public_subnets = {
    a = { cidr_block = "10.30.1.0/24", az_index = 0 }
    b = { cidr_block = "10.30.2.0/24", az_index = 1 }
  }
}

output "web_url" {
  value = module.app.web_url
}

output "web_instance_id" {
  value = module.app.web_instance_id
}

output "vpc_id" {
  value = module.app.vpc_id
}
