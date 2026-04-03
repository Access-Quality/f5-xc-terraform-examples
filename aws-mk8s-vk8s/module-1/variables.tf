variable "project_prefix" {
  description = "Prefix used for resource naming."
  type        = string
}

variable "xc_namespace" {
  description = "XC namespace used by the kiosk resources."
  type        = string
}

variable "xc_api_url" {
  description = "F5 Distributed Cloud API URL."
  type        = string
}

variable "xc_api_p12_file" {
  description = "Path to the XC API P12 credential file."
  type        = string
}

variable "kubeconfig_path" {
  description = "Path to the dynamically generated mK8s kubeconfig."
  type        = string
}

variable "app_stack_name" {
  description = "XC App Stack site name where the VIPs will be advertised."
  type        = string
}

variable "recommendations_origin_dns" {
  description = "DNS name for the recommendations service origin."
  type        = string
  default     = "recommendations.buytime.sr.f5-cloud-demo.com"
}

variable "recommendations_origin_port" {
  description = "Port used by the recommendations service origin."
  type        = number
  default     = 443
}