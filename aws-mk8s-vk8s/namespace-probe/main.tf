data "volterra_namespace" "probe" {
  name = var.xc_namespace
}

output "namespace_name" {
  value = data.volterra_namespace.probe.name
}