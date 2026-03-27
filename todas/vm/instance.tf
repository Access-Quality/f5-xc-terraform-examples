resource "aws_key_pair" "arcadia" {
  key_name   = format("%s-arcadia-key-%s", local.project_prefix, local.build_suffix)
  public_key = var.ssh_key
}

resource "aws_instance" "arcadia" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type

  vpc_security_group_ids = [local.sg_id]
  subnet_id              = local.subnet_id
  key_name               = aws_key_pair.arcadia.key_name

  user_data_base64 = base64encode(templatefile("${path.module}/userdata.sh", {
    arcadia_domain = var.arcadia_domain
    dvwa_domain    = var.dvwa_domain
    boutique_domain = var.boutique_domain
  }))
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 20
  }

  tags = {
    Name = format("%s-arcadia-%s", local.project_prefix, local.build_suffix)
  }

  monitoring              = true
  disable_api_termination = false
  ebs_optimized           = true
}

resource "aws_eip" "arcadia" {
  instance = aws_instance.arcadia.id
  domain   = "vpc"

  tags = {
    Name = format("%s-arcadia-eip-%s", local.project_prefix, local.build_suffix)
  }
}
