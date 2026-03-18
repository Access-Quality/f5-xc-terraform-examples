data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = format("%s-vpc-%s", var.project_prefix, random_id.build_suffix.hex)
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = format("%s-igw-%s", var.project_prefix, random_id.build_suffix.hex)
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = format("%s-subnet-%s", var.project_prefix, random_id.build_suffix.hex)
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = format("%s-rt-%s", var.project_prefix, random_id.build_suffix.hex)
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.main.id
}

# NAT Gateway para que la EC2 privada tenga salida a internet (docker pull)
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = format("%s-nat-eip-%s", var.project_prefix, random_id.build_suffix.hex)
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = format("%s-nat-%s", var.project_prefix, random_id.build_suffix.hex)
  }

  depends_on = [aws_internet_gateway.igw]
}

# Subnet privada para DVWA (acceso a internet via NAT)
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = format("%s-private-subnet-%s", var.project_prefix, random_id.build_suffix.hex)
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = format("%s-private-rt-%s", var.project_prefix, random_id.build_suffix.hex)
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
resource "aws_subnet" "ce" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.ce_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = format("%s-ce-subnet-%s", var.project_prefix, random_id.build_suffix.hex)
  }
}

resource "aws_route_table" "ce" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = format("%s-ce-rt-%s", var.project_prefix, random_id.build_suffix.hex)
  }
}

resource "aws_route_table_association" "ce" {
  subnet_id      = aws_subnet.ce.id
  route_table_id = aws_route_table.ce.id
}
