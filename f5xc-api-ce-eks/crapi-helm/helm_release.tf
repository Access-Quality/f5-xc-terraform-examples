resource "helm_release" "crapi" {
  name             = "crapi"
  chart            = "./helm"
  namespace        = "crapi"
  create_namespace = true
  wait             = false
  values = [
    file("./helm/values.yaml")
  ]
}