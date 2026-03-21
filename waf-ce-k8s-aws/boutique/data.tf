data "tfe_outputs" "infra" {
  organization = var.tf_cloud_organization
  workspace = var.tf_cloud_workspace_infra
}
data "tfe_outputs" "eks" {
  organization = var.tf_cloud_organization
  workspace = var.tf_cloud_workspace_eks
}
data "tfe_outputs" "app" {
  organization = var.tf_cloud_organization
  workspace = var.tf_cloud_workspace_boutique
}
data "aws_eks_cluster_auth" "auth" {
  name = data.tfe_outputs.eks.values.cluster_name
}



