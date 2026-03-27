output "vm_ip" {
  value       = aws_eip.arcadia.public_ip
  description = "Public IP of the EC2 instance hosting Arcadia and DVWA"
  sensitive   = true
}

output "origin_port" {
  value       = 80
  description = "Port where the host nginx reverse proxy is listening"
}

output "arcadia_port" {
  value       = 80
  description = "Port where Arcadia is exposed through the host nginx reverse proxy"
}

output "dvwa_port" {
  value       = 80
  description = "Port where DVWA is exposed through the host nginx reverse proxy"
}
