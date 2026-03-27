resource "aws_security_group" "apps" {
  name        = format("%s-sg-%s", var.project_prefix, random_id.build_suffix.hex)
  description = "Security group for the shared AWS origin without nginx"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 18080
    to_port     = 18087
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Direct service ports for Arcadia, DVWA, Boutique, crAPI and Mailhog"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_src_addr]
    description = "SSH"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = format("%s-sg-%s", var.project_prefix, random_id.build_suffix.hex)
  }
}