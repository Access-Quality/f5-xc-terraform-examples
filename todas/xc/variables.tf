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
  description = "TFC workspace name containing VM outputs (vm_ip, arcadia_port)"
}

variable "api_url" {
  type        = string
  description = "F5 XC tenant API URL (e.g. https://tenant.console.ves.volterra.io/api)"
}

variable "xc_namespace" {
  type        = string
  description = "F5 XC namespace where objects will be created (must already exist)"
}

variable "arcadia_domain" {
  type        = string
  description = "FQDN for Arcadia (e.g. arcadia-aws.prod.example.com)"
}

variable "dvwa_domain" {
  type        = string
  description = "FQDN for DVWA (e.g. dvwa-aws.prod.example.com)"
}

variable "xc_waf_blocking" {
  type        = bool
  description = "Set WAF to blocking (true) or monitoring (false) mode"
  default     = true
}

variable "xc_api_spec" {
  type        = list(string)
  description = "Internal F5 XC object store path(s) for the Arcadia swagger spec (set by workflow after upload)"
  default     = []
}

variable "xc_bot_defense" {
  type        = bool
  description = "Enable Bot Defense on the HTTP Load Balancer (true = enabled, false = disabled)"
  default     = false
}
