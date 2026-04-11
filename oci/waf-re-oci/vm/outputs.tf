output "vm_ip" {
  value       = oci_core_instance.arcadia.public_ip
  description = "Public IP of the Arcadia OCI instance"
  sensitive   = true
}

output "arcadia_port" {
  value       = 8080
  description = "Port where Arcadia nginx proxy is listening"
}
