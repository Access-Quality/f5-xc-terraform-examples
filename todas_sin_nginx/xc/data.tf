data "tfe_outputs" "infra" {
  organization = var.tf_cloud_organization
  workspace    = var.tf_cloud_workspace_infra
}

data "tfe_outputs" "vm" {
  organization = var.tf_cloud_organization
  workspace    = var.tf_cloud_workspace_vm
}