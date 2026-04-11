variable "project_prefix" {
  type        = string
  description = "Prefix for all OCI resources"
  default     = "waf-re-oci"
}

variable "oci_region" {
  type        = string
  description = "OCI region where resources will be created"
}

variable "tenancy_ocid" {
  type        = string
  description = "OCID of the OCI tenancy"
}

variable "user_ocid" {
  type        = string
  description = "OCID of the OCI user for API authentication"
}

variable "fingerprint" {
  type        = string
  description = "Fingerprint of the OCI API key"
}

variable "private_key" {
  type        = string
  description = "PEM private key content for OCI API authentication"
  sensitive   = true
}

variable "compartment_ocid" {
  type        = string
  description = "OCID of the OCI compartment where resources will be created"
}

variable "vcn_cidr" {
  type        = string
  description = "CIDR block for the VCN"
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
