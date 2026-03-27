locals {
  project_prefix     = data.tfe_outputs.infra.values.project_prefix
  build_suffix       = data.tfe_outputs.infra.values.build_suffix
  origin_ip          = data.tfe_outputs.vm.values.vm_ip
  arcadia_main_port  = tostring(data.tfe_outputs.vm.values.arcadia_main_port)
  arcadia_files_port = tostring(data.tfe_outputs.vm.values.arcadia_files_port)
  arcadia_api_port   = tostring(data.tfe_outputs.vm.values.arcadia_api_port)
  arcadia_app3_port  = tostring(data.tfe_outputs.vm.values.arcadia_app3_port)
  dvwa_port          = tostring(data.tfe_outputs.vm.values.dvwa_port)
  boutique_port      = tostring(data.tfe_outputs.vm.values.boutique_port)
  crapi_port         = tostring(data.tfe_outputs.vm.values.crapi_port)
  mailhog_port       = tostring(data.tfe_outputs.vm.values.mailhog_port)

  origin_pools = {
    arcadia_main = {
      port = local.arcadia_main_port
    }
    arcadia_files = {
      port = local.arcadia_files_port
    }
    arcadia_api = {
      port = local.arcadia_api_port
    }
    arcadia_app3 = {
      port = local.arcadia_app3_port
    }
    dvwa = {
      port = local.dvwa_port
    }
    boutique = {
      port = local.boutique_port
    }
    crapi = {
      port = local.crapi_port
    }
    mailhog = {
      port = local.mailhog_port
    }
  }

  loadbalancers = {
    arcadia = {
      description      = "HTTP LB with WAF for Arcadia on AWS RE with dedicated XC LB"
      domains          = [var.arcadia_domain]
      default_pool_key = "arcadia_main"
      route_definitions = [
        {
          host        = var.arcadia_domain
          path_prefix = "/files"
          pool_key    = "arcadia_files"
        },
        {
          host        = var.arcadia_domain
          path_prefix = "/api"
          pool_key    = "arcadia_api"
        },
        {
          host        = var.arcadia_domain
          path_prefix = "/app3"
          pool_key    = "arcadia_app3"
        }
      ]
    }
    dvwa = {
      description       = "HTTP LB with WAF for DVWA on AWS RE with dedicated XC LB"
      domains           = [var.dvwa_domain]
      default_pool_key  = "dvwa"
      route_definitions = []
    }
    boutique = {
      description       = "HTTP LB with WAF for Online Boutique on AWS RE with dedicated XC LB"
      domains           = [var.boutique_domain]
      default_pool_key  = "boutique"
      route_definitions = []
    }
    crapi = {
      description      = "HTTP LB with WAF for crAPI and Mailhog on AWS RE with dedicated XC LB"
      domains          = [var.crapi_domain, var.mailhog_domain]
      default_pool_key = "crapi"
      route_definitions = [
        {
          host        = var.mailhog_domain
          path_prefix = "/"
          pool_key    = "mailhog"
        }
      ]
    }
  }
}