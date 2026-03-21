output "vm_ip" {
  value       = aws_eip.arcadia.public_ip
  description = "Public IP of the Arcadia EC2 instance"
  sensitive   = true
}

output "arcadia_port" {
  value       = 8080
  description = "Port where Arcadia nginx proxy is listening"
}
