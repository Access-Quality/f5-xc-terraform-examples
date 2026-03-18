variable "project_prefix" {
  type        = string
  description = "Prefix for all AWS resources"
  default     = "waf-re-ac-aws"
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

variable "ce_subnet_cidr" {
  type        = string
  description = "CIDR block for the CE private subnet (no internet route - required by F5 XC)"
  default     = "10.0.2.0/24"
}

variable "private_subnet_cidr" {
  type        = string
  description = "CIDR block for the private subnet (DVWA EC2, egress via NAT)"
  default     = "10.0.3.0/24"
}

variable "admin_src_addr" {
  type        = string
  description = "Allowed source IP prefix for SSH access"
  default     = "0.0.0.0/0"
}
