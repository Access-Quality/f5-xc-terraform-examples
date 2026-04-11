output "project_prefix" {
  value = var.project_prefix
}

output "build_suffix" {
  value = random_id.build_suffix.hex
}

output "oci_region" {
  value = var.oci_region
}

output "vcn_id" {
  value = oci_core_vcn.main.id
}

output "subnet_id" {
  value = oci_core_subnet.public.id
}

output "security_list_id" {
  value = oci_core_security_list.arcadia.id
}

output "compartment_ocid" {
  value = var.compartment_ocid
}
