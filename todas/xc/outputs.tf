output "arcadia_lb_name" {
  value = nonsensitive(volterra_http_loadbalancer.lb_https.name)
}

output "dvwa_lb_name" {
  value = nonsensitive(volterra_http_loadbalancer.dvwa_lb.name)
}

output "xc_waf_name" {
  value = nonsensitive(volterra_app_firewall.waap-tf.name)
}

output "arcadia_endpoint" {
  value = var.arcadia_domain
}

output "dvwa_endpoint" {
  value = var.dvwa_domain
}

output "arcadia_lb_cname" {
  value = volterra_http_loadbalancer.lb_https.cname
}

output "dvwa_lb_cname" {
  value = volterra_http_loadbalancer.dvwa_lb.cname
}
