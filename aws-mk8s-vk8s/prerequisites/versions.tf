terraform {
  required_version = ">= 1.4.0"

  backend "remote" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "=6.11.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    volterra = {
      source  = "volterraedge/volterra"
      version = "=0.11.48"
    }
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

provider "volterra" {
  api_p12_file = var.xc_api_p12_file
  url          = var.xc_api_url
}