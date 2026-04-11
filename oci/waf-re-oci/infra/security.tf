resource "oci_core_security_list" "arcadia" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = format("%s-sl-%s", var.project_prefix, random_id.build_suffix.hex)

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "Arcadia nginx proxy"
    tcp_options {
      min = 8080
      max = 8080
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "HTTP"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = var.admin_src_addr
    description = "SSH"
    tcp_options {
      min = 22
      max = 22
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}
