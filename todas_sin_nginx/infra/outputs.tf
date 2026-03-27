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
  value = aws_subnet.public.id
}

output "sg_id" {
  value = aws_security_group.apps.id
}