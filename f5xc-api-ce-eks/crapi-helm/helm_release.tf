resource "helm_release" "crapi" {
  name             = "crapi"
  chart            = "./helm"
  namespace        = "crapi"
  create_namespace = true
  wait             = false
  values = [
    file("./helm/values.yaml")
  ]

  set {
    name  = "chatbot.enabled"
    value = tostring(var.chatbot_enabled)
  }

  set_sensitive {
    name  = "chatbot.openaiApiKey"
    value = var.chatbot_openai_key
  }
}