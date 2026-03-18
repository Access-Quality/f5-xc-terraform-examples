output "project_prefix" {
  value = var.project_prefix
}

output "build_suffix" {
  value = random_id.build_suffix.hex
}

output "aws_region" {
  value = var.aws_region
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_id" {
  value = aws_subnet.private.id
  description = "Private subnet ID for DVWA EC2 (egress via NAT)"
}

output "ce_subnet_id" {
  value = aws_subnet.ce.id
}

output "aws_az" {
  value = data.aws_availability_zones.available.names[0]
}

output "sg_id" {
  value = aws_security_group.arcadia.id
}

# Boolean outputs required by xc/data.tf to conditionally load workspaces
output "bigip" {
  value = false
}

output "nap" {
  value = false
}

output "nic" {
  value = false
}

output "aks-cluster" {
  value = false
}

output "azure-vm" {
  value = false
}
