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
    key          = "assignment1/staging/terraform.tfstate"
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
      Environment = "staging"
    }
  }
}

module "app" {
  source = "../modules/app"

  environment   = "staging"
  owner         = "azaia2"
  instance_type = "t3.micro"
  vpc_cidr      = "10.20.0.0/16"

  public_subnets = {
    a = { cidr_block = "10.20.1.0/24", az_index = 0 }
    b = { cidr_block = "10.20.2.0/24", az_index = 1 }
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
