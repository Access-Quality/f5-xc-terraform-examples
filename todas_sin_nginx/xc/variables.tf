variable "tf_cloud_organization" {
  type        = string
  description = "Terraform Cloud organization name"
}

variable "tf_cloud_workspace_infra" {
  type        = string
  description = "TFC workspace name containing infra outputs"
}

variable "tf_cloud_workspace_vm" {
  type        = string
  description = "TFC workspace name containing VM outputs"
}

variable "api_url" {
  type        = string
  description = "F5 XC tenant API URL"
}

variable "xc_namespace" {
  type        = string
  description = "F5 XC namespace where objects will be created"
}

variable "arcadia_domain" {
  type        = string
  description = "FQDN for Arcadia"
}

variable "dvwa_domain" {
  type        = string
  description = "FQDN for DVWA"
}

variable "boutique_domain" {
  type        = string
  description = "FQDN for Online Boutique"
}

variable "crapi_domain" {
  type        = string
  description = "FQDN for crAPI"
}

variable "mailhog_domain" {
  type        = string
  description = "FQDN for Mailhog"
}

variable "xc_waf_blocking" {
  type        = bool
  description = "Set WAF to blocking or monitoring mode"
  default     = true
}

variable "xc_api_discovery" {
  type        = bool
  description = "Enable API Discovery globally on the shared HTTP Load Balancer"
  default     = false
}

variable "xc_api_protection" {
  type        = bool
  description = "Enable API Protection globally on the shared HTTP Load Balancer"
  default     = false
}

variable "xc_api_specs" {
  type        = list(string)
  description = "Internal F5 XC object store paths for uploaded OpenAPI specs"
  default     = []
}

variable "xc_bot_defense" {
  type        = bool
  description = "Enable Bot Defense on the HTTP Load Balancer"
  default     = false
}