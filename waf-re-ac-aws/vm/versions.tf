terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = ">= 0.51"
    }
  }
}
