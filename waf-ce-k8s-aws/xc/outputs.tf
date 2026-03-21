output "xc_lb_name" {
  value = nonsensitive(volterra_http_loadbalancer.lb_https.name)
}
output "xc_waf_name" {
  value = nonsensitive(volterra_app_firewall.waap-tf.name)
}
output "endpoint" {
  value = var.app_domain
}
output "az_ce_site_pub_ip" {
  value = var.aws_ce_site ? try(regex("master_public_ip_address = \"((?:\\d{1,3}\\.){3}\\d{1,3})\"", volterra_tf_params_action.example[0].tf_output), null) : null
}
output "lb_cname" {
  value = volterra_http_loadbalancer.lb_https.cname
}
