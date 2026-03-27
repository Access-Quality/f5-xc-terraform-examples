output "vm_ip" {
  value       = aws_eip.arcadia.public_ip
  description = "Public IP of the EC2 instance hosting the shared origin"
  sensitive   = true
}

output "origin_port" {
  value       = 18080
  description = "Default Arcadia main port"
}

output "arcadia_main_port" {
  value       = 18080
  description = "Port where Arcadia main app is exposed directly on the host"
}

output "arcadia_files_port" {
  value       = 18081
  description = "Port where Arcadia files backend is exposed directly on the host"
}

output "arcadia_api_port" {
  value       = 18082
  description = "Port where Arcadia API backend is exposed directly on the host"
}

output "arcadia_app3_port" {
  value       = 18083
  description = "Port where Arcadia app3 backend is exposed directly on the host"
}

output "dvwa_port" {
  value       = 18084
  description = "Port where DVWA is exposed directly on the host"
}

output "boutique_port" {
  value       = 18085
  description = "Port where Online Boutique is exposed directly on the host"
}

output "crapi_port" {
  value       = 18086
  description = "Port where crAPI web is exposed directly on the host"
}

output "mailhog_port" {
  value       = 18087
  description = "Port where Mailhog is exposed directly on the host"
}