#TF Cloud
variable "tf_cloud_organization" {
  type = string
  description = "TF cloud org (Value set in TF cloud)"
}

variable "tf_cloud_workspace_infra" {
  type        = string
  description = "TF Cloud workspace name for infra outputs"
}

variable "tf_cloud_workspace_eks" {
  type        = string
  description = "TF Cloud workspace name for EKS outputs"
}

variable "tf_cloud_workspace_boutique" {
  type        = string
  description = "TF Cloud workspace name for boutique outputs (self)"
}

variable "ssh_key" {
  type        = string
  description = "Only present for warning handling with TF cloud variable set"
}

variable "aws_access_key" {
  description = "AWS Access Key ID"
  type        = string
  sensitive   = true
  default     = null
}

variable "aws_secret_key" {
  description = "AWS Secret Key ID"
  type        = string
  sensitive   = true
  default     = null
}