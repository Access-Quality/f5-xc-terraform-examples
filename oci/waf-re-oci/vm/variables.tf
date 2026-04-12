variable "tf_cloud_organization" {
  type        = string
  description = "Terraform Cloud organization name"
}

variable "tf_cloud_workspace_infra" {
  type        = string
  description = "TFC workspace name containing infra outputs"
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

variable "ssh_key" {
  type        = string
  description = "SSH public key in ssh-rsa format"
}

variable "instance_shape" {
  type        = string
  description = "OCI compute shape for the Arcadia instance"
  default     = "VM.Standard.E2.1"
}
