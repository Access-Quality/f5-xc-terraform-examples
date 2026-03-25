resource "volterra_api_definition" "arcadia" {
  name      = format("%s-xcapi-%s", local.project_prefix, local.build_suffix)
  namespace = var.xc_namespace

  depends_on = [null_resource.namespace_ready]

  swagger_specs = [
    "https://raw.githubusercontent.com/Access-Quality/f5-xc-terraform-examples/main/arcadia/arcadia-oas3-2.0.1.json"
  ]
}

resource "volterra_origin_pool" "op" {
  depends_on  = [null_resource.namespace_ready]
  name        = format("%s-xcop-%s", local.project_prefix, local.build_suffix)
  namespace   = var.xc_namespace
  description = format("Origin pool pointing to Arcadia at %s:%s", local.origin_ip, local.origin_port)

  origin_servers {
    public_ip {
      ip = local.origin_ip
    }
  }

  no_tls                 = true
  port                   = local.origin_port
  endpoint_selection     = "LOCAL_PREFERRED"
  loadbalancer_algorithm = "LB_OVERRIDE"
}

resource "volterra_http_loadbalancer" "lb_https" {
  depends_on  = [volterra_origin_pool.op, volterra_app_firewall.waap-tf, volterra_api_definition.arcadia]
  name        = format("%s-xclb-%s", local.project_prefix, local.build_suffix)
  namespace   = var.xc_namespace
  description = format("HTTP LB with WAF for Arcadia Finance on AWS RE")

  domains                         = [var.app_domain]
  advertise_on_public_default_vip = true

  default_route_pools {
    pool {
      name      = volterra_origin_pool.op.name
      namespace = var.xc_namespace
    }
    weight = 1
  }

  http {
    port = 80
  }

  app_firewall {
    name      = volterra_app_firewall.waap-tf.name
    namespace = var.xc_namespace
  }

  api_definition {
    name      = volterra_api_definition.arcadia.name
    namespace = var.xc_namespace
  }

  enable_api_discovery {
    discovered_api_settings {
      purge_duration_for_inactive_discovered_apis = 7
    }
  }

  api_protection_rules {
    api_groups_rules {
      base_path = "/"
      metadata {
        name = "block-undocumented"
      }
      action {
        deny = true
      }
    }
  }

  disable_waf                     = false
  round_robin                     = true
  service_policies_from_namespace = true
  user_id_client_ip               = true
  source_ip_stickiness            = true
}
