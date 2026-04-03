variable "project_prefix" {
  description = "Prefix used for AWS and XC resource names."
  type        = string
}

variable "xc_namespace" {
  description = "XC namespace used for module 1 resources."
  type        = string
}

variable "create_xc_namespace" {
  description = "Whether prerequisites should create the XC namespace when it does not already exist."
  type        = bool
  default     = true
}

variable "xc_api_url" {
  description = "F5 Distributed Cloud API URL."
  type        = string
}

variable "xc_api_p12_file" {
  description = "Path to the XC API P12 credential file."
  type        = string
}

variable "aws_region" {
  description = "AWS region where the App Stack site will be created."
  type        = string
}

variable "aws_access_key" {
  description = "AWS access key used by Terraform."
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS secret key used by Terraform."
  type        = string
  sensitive   = true
}

variable "vpc_cidr" {
  description = "Primary VPC CIDR for the App Stack site."
  type        = string

  validation {
    condition     = length(trimspace(var.vpc_cidr)) > 0 && can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a non-empty valid CIDR block, for example 10.0.0.0/16."
  }
}
