terraform {
  required_version = ">= 1.0.0"
  required_providers {
    volterra = {
      source  = "volterraedge/volterra"
      version = ">= 0.11.34"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = ">= 0.51"
    }
  }
}
