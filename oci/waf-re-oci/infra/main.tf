provider "oci" {
  region              = var.oci_region
  tenancy_ocid        = var.tenancy_ocid
  user_ocid           = var.user_ocid
  fingerprint         = var.fingerprint
  private_key_content = var.private_key
}

resource "random_id" "build_suffix" {
  byte_length = 2
}
