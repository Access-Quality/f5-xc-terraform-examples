provider "aws" {
  region = var.aws_region
}

resource "random_id" "build_suffix" {
  byte_length = 2
}