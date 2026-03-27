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
}