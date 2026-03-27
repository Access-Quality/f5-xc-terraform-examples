variable "tf_cloud_organization" {
  type        = string
  description = "Terraform Cloud organization name"
}

variable "tf_cloud_workspace_infra" {
  type        = string
  description = "TFC workspace name containing infra outputs"
}

variable "ssh_key" {
  type        = string
  description = "SSH public key in ssh-rsa format for EC2 key pair"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.xlarge"
}

variable "arcadia_domain" {
  type        = string
  description = "FQDN used to access Arcadia through the reverse proxy"
}

variable "dvwa_domain" {
  type        = string
  description = "FQDN used to access DVWA through the reverse proxy"
}

variable "boutique_domain" {
  type        = string
  description = "FQDN used to access Online Boutique through the reverse proxy"
}

variable "crapi_domain" {
  type        = string
  description = "FQDN used to access crAPI through the reverse proxy"
}

variable "mailhog_domain" {
  type        = string
  description = "FQDN used to access Mailhog through the reverse proxy"
}
