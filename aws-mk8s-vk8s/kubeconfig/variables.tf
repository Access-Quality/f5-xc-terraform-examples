variable "project_prefix" {
  description = "Prefix used to name the temporary kubeconfig credential."
  type        = string
}

variable "site_name" {
  description = "XC site name used to request a site global kubeconfig."
  type        = string
}

variable "xc_namespace" {
  description = "XC namespace that the temporary service credential should be allowed to manage."
  type        = string
}

variable "service_credential_role" {
  description = "XC role assigned to the temporary service credential in required namespaces."
  type        = string
  default     = "ves-io-admin-role"
}

variable "credential_name" {
  description = "Optional explicit name for the temporary service credential."
  type        = string
  default     = ""

  validation {
    condition     = var.credential_name == "" || length(var.credential_name) <= 31
    error_message = "credential_name must be 31 characters or fewer."
  }
}

variable "xc_api_url" {
  description = "F5 Distributed Cloud API URL."
  type        = string
}

variable "xc_api_p12_file" {
  description = "Path to the XC API P12 credential file."
  type        = string
}