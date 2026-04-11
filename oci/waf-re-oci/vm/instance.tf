resource "oci_core_instance" "arcadia" {
  compartment_id      = local.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = format("%s-arcadia-%s", local.project_prefix, local.build_suffix)
  shape               = var.instance_shape

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_22.images[0].id
    boot_volume_size_in_gbs = 50
  }

  create_vnic_details {
    subnet_id        = local.subnet_id
    assign_public_ip = true
    display_name     = format("%s-vnic-%s", local.project_prefix, local.build_suffix)
  }

  metadata = {
    ssh_authorized_keys = var.ssh_key
    user_data           = base64encode(file("${path.module}/userdata.sh"))
  }
}
