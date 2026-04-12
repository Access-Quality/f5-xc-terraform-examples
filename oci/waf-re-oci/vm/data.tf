data "tfe_outputs" "infra" {
  organization = var.tf_cloud_organization
  workspace    = var.tf_cloud_workspace_infra
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu_22" {
  compartment_id           = local.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}
