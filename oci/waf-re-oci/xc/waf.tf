resource "null_resource" "namespace_ready" {}

resource "volterra_app_firewall" "waap-tf" {
  depends_on  = [null_resource.namespace_ready]
  name        = format("%s-xcw-%s", local.project_prefix, local.build_suffix)
  namespace   = var.xc_namespace
  description = format("WAF in block mode for %s", "${local.project_prefix}-xcw-${local.build_suffix}")

  allow_all_response_codes   = true
  default_anonymization      = true
  use_default_blocking_page  = true
  default_bot_setting        = true
  default_detection_settings = true
  use_loadbalancer_setting   = true
  blocking                   = var.xc_waf_blocking
}
