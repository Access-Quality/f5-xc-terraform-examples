locals {
  project_prefix = data.tfe_outputs.infra.values.project_prefix
  build_suffix   = data.tfe_outputs.infra.values.build_suffix
  origin_ip      = data.tfe_outputs.vm.values.vm_ip
  origin_port    = tostring(data.tfe_outputs.vm.values.origin_port)
}
