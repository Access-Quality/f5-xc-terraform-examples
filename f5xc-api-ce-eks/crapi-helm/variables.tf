#TF Cloud
variable "tf_cloud_organization" {
  type = string
  description = "TF cloud org (Value set in TF cloud)"
}

variable "infra_workspace" {
  type        = string
  description = "TF Cloud workspace name for infra"
}

variable "eks_workspace" {
  type        = string
  description = "TF Cloud workspace name for EKS"
}

variable "ssh_key" {
  type        = string
  description = "Only present for warning handling with TF cloud variable set"
  default     = ""
}
