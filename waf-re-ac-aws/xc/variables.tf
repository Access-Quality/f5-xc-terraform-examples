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
  description = "F5 XC namespace donde se crearán los objetos"
}

variable "app_domain" {
  type        = string
  description = "FQDN para la aplicación (e.g. dvwa-aws.example.com)"
}

variable "xc_waf_blocking" {
  type        = bool
  description = "WAF en modo blocking (true) o monitoring (false)"
  default     = true
}

variable "aws_access_key" {
  type        = string
  description = "AWS Access Key ID para crear el CE site"
  sensitive   = true
}

variable "aws_secret_key" {
  type        = string
  description = "AWS Secret Access Key para crear el CE site"
  sensitive   = true
}

variable "ssh_key" {
  type        = string
  description = "SSH public key para el CE node"
}
