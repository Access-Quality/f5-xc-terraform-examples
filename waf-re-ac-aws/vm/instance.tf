resource "aws_key_pair" "dvwa" {
  key_name   = format("%s-dvwa-key-%s", local.project_prefix, local.build_suffix)
  public_key = var.ssh_key
}

resource "aws_instance" "dvwa" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type

  vpc_security_group_ids      = [local.sg_id]
  subnet_id                   = local.subnet_id
  key_name                    = aws_key_pair.dvwa.key_name
  associate_public_ip_address = false

  user_data = filebase64("${path.module}/dvwa_userdata.sh")

  root_block_device {
    volume_size = 20
  }

  tags = {
    Name = format("%s-dvwa-%s", local.project_prefix, local.build_suffix)
  }

  monitoring              = true
  disable_api_termination = false
  ebs_optimized           = true
}
