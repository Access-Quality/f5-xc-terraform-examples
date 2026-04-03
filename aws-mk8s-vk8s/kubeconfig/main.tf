locals {
  raw_name        = lower(join("-", compact([var.project_prefix, var.site_name, "site-kubeconfig"])))
  generated_name  = substr(replace(local.raw_name, "/[^a-z0-9-]/", "-"), 0, 31)
  effective_name  = var.credential_name != "" ? var.credential_name : local.generated_name
  allowed_namespaces = distinct(compact(["system", var.xc_namespace]))
}

resource "volterra_service_credential" "site_kubeconfig" {
  created_at              = timestamp()
  name                    = local.effective_name
  service_credential_type = "SITE_GLOBAL_KUBE_CONFIG"

  dynamic "namespace_roles" {
    for_each = local.allowed_namespaces

    content {
      namespace = namespace_roles.value
      role      = var.service_credential_role
    }
  }

  site_kubeconfig {
    site = var.site_name
  }
}

output "credential_name" {
  description = "Name of the temporary kubeconfig credential."
  value       = volterra_service_credential.site_kubeconfig.name
}

output "kubeconfig_content" {
  description = "Decoded site global kubeconfig content."
  sensitive   = true
  value       = base64decode(volterra_service_credential.site_kubeconfig.data)
}