locals {
  base_name              = join("-", compact([var.project_prefix, var.xc_namespace]))
  kiosk_domain           = "kiosk.${var.xc_namespace}.buytime.internal"
  recommendations_domain = "recommendations.${var.xc_namespace}.buytime.internal"
  kiosk_manifest         = templatefile("${path.module}/templates/appstack-mk8s-kiosk.yaml.tftpl", {
    namespace    = var.xc_namespace
    kiosk_domain = local.kiosk_domain
  })
  kiosk_objects = split("\n---\n", local.kiosk_manifest)
}

resource "kubectl_manifest" "kiosk" {
  count     = length(local.kiosk_objects)
  yaml_body = local.kiosk_objects[count.index]
}

resource "volterra_http_loadbalancer" "kiosk" {
  name      = "${local.base_name}-kiosk-internal"
  namespace = var.xc_namespace

  domains = [local.kiosk_domain]

  http {
    dns_volterra_managed = false
    port                 = "80"
  }

  default_route_pools {
    pool {
      name      = volterra_origin_pool.kiosk.name
      namespace = var.xc_namespace
    }
    priority = 1
    weight   = 1
  }

  advertise_custom {
    advertise_where {
      site {
        site {
          name      = var.app_stack_name
          namespace = "system"
        }
        network = "SITE_NETWORK_INSIDE_AND_OUTSIDE"
      }
    }
  }

  disable_api_definition           = true
  disable_api_discovery            = true
  no_challenge                     = true
  source_ip_stickiness             = true
  disable_malicious_user_detection = true
  disable_rate_limit               = true
  service_policies_from_namespace  = true
  disable_trust_client_ip_headers  = true
  user_id_client_ip                = true
  disable_waf                      = true
}

resource "volterra_origin_pool" "kiosk" {
  name      = "${local.base_name}-kiosk-pool"
  namespace = var.xc_namespace

  origin_servers {
    k8s_service {
      service_name = "kiosk-service.${var.xc_namespace}"

      site_locator {
        site {
          name      = var.app_stack_name
          namespace = "system"
        }
      }

      vk8s_networks = true
    }
  }

  no_tls                 = true
  port                   = 8080
  endpoint_selection     = "LOCAL_PREFERRED"
  loadbalancer_algorithm = "LB_OVERRIDE"

  depends_on = [kubectl_manifest.kiosk]
}

resource "volterra_http_loadbalancer" "recommendations" {
  name      = "${local.base_name}-recommendations"
  namespace = var.xc_namespace

  domains = [local.recommendations_domain]

  http {
    dns_volterra_managed = false
    port                 = "80"
  }

  default_route_pools {
    pool {
      name      = volterra_origin_pool.recommendations.name
      namespace = var.xc_namespace
    }
    priority = 1
    weight   = 1
  }

  advertise_custom {
    advertise_where {
      site {
        site {
          name      = var.app_stack_name
          namespace = "system"
        }
        network = "SITE_NETWORK_INSIDE_AND_OUTSIDE"
      }
    }
  }

  disable_api_definition           = true
  disable_api_discovery            = true
  no_challenge                     = true
  source_ip_stickiness             = true
  disable_malicious_user_detection = true
  disable_rate_limit               = true
  service_policies_from_namespace  = true
  disable_trust_client_ip_headers  = true
  user_id_client_ip                = true
  disable_waf                      = true
}

resource "volterra_origin_pool" "recommendations" {
  name      = "${local.base_name}-recommendations-pool"
  namespace = var.xc_namespace

  origin_servers {
    public_name {
      dns_name = var.recommendations_origin_dns
    }
  }

  use_tls {
    tls_config {
      default_security = true
    }
  }

  port                   = var.recommendations_origin_port
  endpoint_selection     = "LOCAL_PREFERRED"
  loadbalancer_algorithm = "LB_OVERRIDE"
}

output "kiosk_domain" {
  description = "Internal kiosk domain published by the XC HTTP load balancer."
  value       = local.kiosk_domain
}

output "recommendations_domain" {
  description = "Internal recommendations domain published by the XC HTTP load balancer."
  value       = local.recommendations_domain
}