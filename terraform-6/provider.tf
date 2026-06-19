terraform {
  required_providers {
    aws = {
      source  = "registry.terraform.io/hashicorp/aws"
      version = "6.44.0"
    }
    archive = {
      source  = "registry.terraform.io/hashicorp/archive"
      version = "2.7.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
