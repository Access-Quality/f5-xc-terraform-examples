output "xc_lb_name" {
  value = nonsensitive(volterra_http_loadbalancer.applications["arcadia"].name)
}

output "xc_lb_names" {
  value = {
    for name, lb in volterra_http_loadbalancer.applications : name => nonsensitive(lb.name)
  }
}

output "xc_waf_name" {
  value = nonsensitive(volterra_app_firewall.waap-tf.name)
}

output "lb_domains" {
  value = {
    arcadia  = [var.arcadia_domain]
    dvwa     = [var.dvwa_domain]
    boutique = [var.boutique_domain]
    crapi    = [var.crapi_domain, var.mailhog_domain]
  }
}

output "lb_cname" {
  value = volterra_http_loadbalancer.applications["arcadia"].cname
}

output "lb_cnames" {
  value = {
    for name, lb in volterra_http_loadbalancer.applications : name => lb.cname
  }
}