resource "volterra_api_definition" "arcadia" {
  name      = format("%s-xcapi-%s", local.project_prefix, local.build_suffix)
  namespace = var.xc_namespace

  depends_on = [null_resource.namespace_ready]

  swagger_specs = var.xc_api_spec
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

  enable_api_discovery {
    enable_learn_from_redirect_traffic = true
    discovered_api_settings {
      purge_duration_for_inactive_discovered_apis = 7
    }
  }

  api_specification {
    api_definition {
      name      = volterra_api_definition.arcadia.name
      namespace = var.xc_namespace
    }
    validation_all_spec_endpoints {
      validation_mode {
        validation_mode_active {
          request_validation_properties = ["PROPERTY_QUERY_PARAMETERS", "PROPERTY_PATH_PARAMETERS", "PROPERTY_CONTENT_TYPE", "PROPERTY_COOKIE_PARAMETERS", "PROPERTY_HTTP_HEADERS", "PROPERTY_HTTP_BODY"]
          enforcement_block             = false
          enforcement_report            = true
        }
      }
      fall_through_mode {
        fall_through_mode_allow = true
      }
    }
  }

  dynamic "bot_defense" {
    for_each = var.xc_bot_defense ? [1] : []
    content {
      policy {
        javascript_mode   = "SYNC_JS_NO_CACHING"
        disable_js_insert = false
        js_insert_all_pages {
          javascript_location = "AFTER_HEAD"
        }
        disable_mobile_sdk = true
        js_download_path   = "/common.js"
        protected_app_endpoints {
          metadata {
            name = format("%s-bot-login-%s", local.project_prefix, local.build_suffix)
          }
          http_methods = ["METHOD_POST"]
          mitigation {
            flag {
              no_headers = true
            }
          }
          path {
            path = "/trading/auth.php"
          }
          flow_label {
            authentication {
              login {}
            }
          }
        }
      }
      regional_endpoint = "US"
      timeout           = 3000
    }
  }

  disable_waf                     = false
  round_robin                     = true
  service_policies_from_namespace = true
  user_id_client_ip               = true
  source_ip_stickiness            = true
}
