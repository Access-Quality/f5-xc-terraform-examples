variable "project_prefix" {
  type        = string
  description = "Prefix for all AWS resources"
  default     = "sec-re-aws-todas-4lbs"
}

variable "aws_region" {
  type        = string
  description = "AWS region where resources will be created"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  type        = string
  description = "CIDR block for the public subnet"
  default     = "10.0.1.0/24"
}

variable "admin_src_addr" {
  type        = string
  description = "Allowed source IP prefix for SSH access"
  default     = "0.0.0.0/0"
}

variable "tf_cloud_organization" {
  type        = string
  description = "Terraform Cloud organization name"
}