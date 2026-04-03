locals {
  base_name          = join("-", compact([var.project_prefix, var.xc_namespace]))
  aws_site_name      = "aws-${local.base_name}"
  cloud_cred_name    = "${local.base_name}-aws-cred"
  k8s_cluster_name   = "${local.aws_site_name}-mk8s"
  vpc_name           = "${local.base_name}-vpc"
  subnet_a_cidr      = cidrsubnet(var.vpc_cidr, 8, 10)
  app_stack_location = "${local.base_name}-app-stack"
  effective_namespace = var.create_xc_namespace ? volterra_namespace.app_namespace[0].name : data.volterra_namespace.app_namespace[0].name
}

resource "volterra_namespace" "app_namespace" {
  count = var.create_xc_namespace ? 1 : 0

  name = var.xc_namespace
}

data "volterra_namespace" "app_namespace" {
  count = var.create_xc_namespace ? 0 : 1

  name = var.xc_namespace
}

resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name        = local.vpc_name
    Environment = var.xc_namespace
    Project     = var.project_prefix
  }
}

resource "aws_subnet" "subnet_a" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = local.subnet_a_cidr

  tags = {
    Name        = "${local.vpc_name}-subnet-a"
    Environment = var.xc_namespace
    Project     = var.project_prefix
  }
}

resource "tls_private_key" "appstack_key" {
  algorithm = "RSA"
}

resource "volterra_cloud_credentials" "aws_cred" {
  name      = local.cloud_cred_name
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

resource "volterra_k8s_cluster" "mk8s" {
  name      = local.k8s_cluster_name
  namespace = "system"

  cluster_wide_app_list {
    cluster_wide_apps {
      dashboard {}
    }
  }

  use_default_cluster_role_bindings = true
  use_default_cluster_roles         = true
  cluster_scoped_access_deny        = true
  global_access_enable              = true
  no_insecure_registries            = true
  use_default_psp                   = true

  local_access_config {
    local_domain = "buytime.internal"
  }
}

resource "volterra_aws_vpc_site" "appstack" {
  name       = local.aws_site_name
  namespace  = "system"
  aws_region = var.aws_region

  labels = {
    location = local.app_stack_location
  }

  blocked_services {
    blocked_sevice {
      dns = false
    }
  }

  aws_cred {
    name      = volterra_cloud_credentials.aws_cred.name
    namespace = volterra_cloud_credentials.aws_cred.namespace
  }

  vpc {
    vpc_id = aws_vpc.vpc.id
  }

  direct_connect_disabled   = true
  instance_type             = "t3.xlarge"
  disable_internet_vip      = true
  logs_streaming_disabled   = true
  ssh_key                   = tls_private_key.appstack_key.public_key_openssh
  no_worker_nodes           = true

  voltstack_cluster {
    aws_certified_hw = "aws-byol-voltstack-combo"

    az_nodes {
      aws_az_name = "${var.aws_region}a"

      local_subnet {
        existing_subnet_id = aws_subnet.subnet_a.id
      }
    }

    k8s_cluster {
      name = volterra_k8s_cluster.mk8s.name
    }
  }

  depends_on = [
    volterra_cloud_credentials.aws_cred,
    aws_vpc.vpc,
    aws_subnet.subnet_a,
  ]
}

resource "volterra_cloud_site_labels" "appstack_labels" {
  name             = volterra_aws_vpc_site.appstack.name
  site_type        = "aws_vpc_site"
  labels           = {}
  ignore_on_delete = true
}

resource "volterra_tf_params_action" "appstack_apply" {
  site_name        = volterra_aws_vpc_site.appstack.name
  site_kind        = "aws_vpc_site"
  action           = "apply"
  wait_for_action  = true
  ignore_on_update = true

  depends_on = [volterra_aws_vpc_site.appstack]
}

data "aws_instance" "appstack" {
  instance_tags = {
    "ves-io-site-name" = local.aws_site_name
  }

  filter {
    name   = "subnet-id"
    values = [aws_subnet.subnet_a.id]
  }

  depends_on = [volterra_tf_params_action.appstack_apply]
}

data "aws_network_interface" "appstack" {
  filter {
    name   = "attachment.instance-id"
    values = [data.aws_instance.appstack.id]
  }

  filter {
    name   = "subnet-id"
    values = [aws_subnet.subnet_a.id]
  }

  depends_on = [volterra_tf_params_action.appstack_apply]
}

resource "tls_private_key" "kiosk_key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kiosk_key_pair" {
  key_name   = "${local.base_name}-kiosk-key"
  public_key = tls_private_key.kiosk_key_pair.public_key_openssh
}

data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base*"]
  }
}

resource "aws_security_group" "kiosk_sg" {
  name        = "${local.base_name}-kiosk-sg"
  description = "Allow RDP connections"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow incoming RDP connections"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.base_name}-kiosk-sg"
    Environment = var.xc_namespace
    Project     = var.project_prefix
  }
}

resource "aws_instance" "kiosk" {
  ami                         = data.aws_ami.windows.id
  instance_type               = "t3.large"
  subnet_id                   = aws_subnet.subnet_a.id
  vpc_security_group_ids      = [aws_security_group.kiosk_sg.id]
  source_dest_check           = false
  key_name                    = aws_key_pair.kiosk_key_pair.key_name
  associate_public_ip_address = true
  get_password_data           = true

  root_block_device {
    volume_size           = 30
    volume_type           = "gp2"
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name        = "${local.base_name}-kiosk"
    Environment = var.xc_namespace
    Project     = var.project_prefix
  }
}

output "app_stack_name" {
  description = "XC AWS App Stack site name."
  value       = volterra_aws_vpc_site.appstack.name
}

output "mk8s_cluster_name" {
  description = "XC managed k8s cluster name."
  value       = volterra_k8s_cluster.mk8s.name
}

output "xc_namespace" {
  description = "XC namespace used by module 1."
  value       = local.effective_namespace
}

output "appstack_private_ip" {
  description = "Private IP of the App Stack instance."
  value       = data.aws_network_interface.appstack.private_ip
}

output "aws_vpc_id" {
  description = "AWS VPC ID for the App Stack deployment."
  value       = aws_vpc.vpc.id
}

output "aws_subnet_a_id" {
  description = "AWS subnet ID used by the App Stack deployment."
  value       = aws_subnet.subnet_a.id
}

output "kiosk_address" {
  description = "Public IP of the kiosk VM."
  value       = aws_instance.kiosk.public_ip
}

output "kiosk_user" {
  description = "Username for the kiosk VM."
  value       = "administrator"
}

output "kiosk_password" {
  description = "Decrypted Windows administrator password for the kiosk VM."
  sensitive   = true
  value       = rsadecrypt(aws_instance.kiosk.password_data, tls_private_key.kiosk_key_pair.private_key_pem)
}