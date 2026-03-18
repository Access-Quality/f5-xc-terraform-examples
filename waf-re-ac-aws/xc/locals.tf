locals {
  project_prefix = data.tfe_outputs.infra.values.project_prefix
  build_suffix   = data.tfe_outputs.infra.values.build_suffix
  aws_region     = data.tfe_outputs.infra.values.aws_region
  vpc_id         = data.tfe_outputs.infra.values.vpc_id
  subnet_id      = data.tfe_outputs.infra.values.subnet_id
  ce_subnet_id   = data.tfe_outputs.infra.values.ce_subnet_id
  aws_az         = data.tfe_outputs.infra.values.aws_az
  origin_ip      = data.tfe_outputs.vm.values.vm_ip
  origin_port    = tostring(data.tfe_outputs.vm.values.dvwa_port)
}
