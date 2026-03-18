resource "volterra_cloud_credentials" "aws_cred" {
  name      = format("%s-aws-creds-%s", local.project_prefix, local.build_suffix)
  namespace = "system"

  aws_secret_key {
    access_key = var.aws_access_key
    secret_key {
      clear_secret_info {
        url = "string:///${base64encode(var.aws_secret_key)}"
      }
    }
  }
}

resource "volterra_aws_vpc_site" "ce" {
  name       = format("%s-ce-%s", local.project_prefix, local.build_suffix)
  namespace  = "system"
  aws_region = local.aws_region

  aws_cred {
    name      = volterra_cloud_credentials.aws_cred.name
    namespace = "system"
  }

  instance_type = "t3.xlarge"

  vpc {
    vpc_id = local.vpc_id
  }

  ingress_gw {
    aws_certified_hw = "aws-byol-voltmesh"
    az_nodes {
      aws_az_name = local.aws_az
      disk_size   = 0
      local_subnet {
        existing_subnet_id = local.ce_subnet_id
      }
    }
  }

  logs_streaming_disabled = true
  no_worker_nodes         = true
  ssh_key                 = var.ssh_key
}

resource "null_resource" "wait_for_ce_validation" {
  depends_on = [volterra_aws_vpc_site.ce]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "${path.module}/check_ce_status.sh ${var.api_url}/register/namespaces/system/site/${volterra_aws_vpc_site.ce.name} ${path.module}/api.p12 '' 600 cert $VES_P12_PASSWORD"
  }
}

resource "volterra_tf_params_action" "apply_ce" {
  depends_on      = [null_resource.wait_for_ce_validation]
  site_name       = volterra_aws_vpc_site.ce.name
  site_kind       = "aws_vpc_site"
  action          = "apply"
  wait_for_action = true
}
