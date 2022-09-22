terraform {
  required_version = ">=1"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = "us-east-1"
}

module "encrypt-decrypt" {
  source      = "../terraform/modules/terraform-aws-ecr-docker-image"
  image_name  = "encrypt-decrypt-s3-docker"
  source_path = "${path.module}/src"
}
