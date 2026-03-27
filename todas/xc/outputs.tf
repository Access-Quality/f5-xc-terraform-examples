output "xc_lb_name" {
  value = nonsensitive(volterra_http_loadbalancer.lb_https.name)
}

output "xc_waf_name" {
  value = nonsensitive(volterra_app_firewall.waap-tf.name)
}

output "lb_domains" {
  value = [var.arcadia_domain, var.dvwa_domain]
}

output "lb_cname" {
  value = volterra_http_loadbalancer.lb_https.cname
}
