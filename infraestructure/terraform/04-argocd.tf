module "argocd_capability" {
  source  = "terraform-aws-modules/eks/aws//modules/capability"
  version = "~> 21.0"

  name         = "${local.cluster_name}-argocd"
  cluster_name = module.eks.cluster_name
  type         = "ARGOCD"

  configuration = {
    argo_cd = {
      aws_idc = {
        idc_instance_arn = local.sso_instance_arn
      }
      namespace = "argocd"
      rbac_role_mapping = [{
        role = "ADMIN"
        identity = [{
          id   = aws_identitystore_group.argocd_admins.group_id
          type = "SSO_GROUP"
        }]
      }]
    }
  }

  tags = {
    "Environment" = "dev"
    "Project"     = "eks-argocd"
  }

  depends_on = [module.eks, aws_identitystore_group_membership.admin]
}

resource "terraform_data" "argocd_clusterrole" {
  triggers_replace = [filesha256("${path.root}/argocd/clusterrole.yaml")]

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name} && kubectl apply -f ${path.root}/argocd/clusterrole.yaml"
  }

  depends_on = [module.argocd_capability, terraform_data.kubeconfig]
}

resource "terraform_data" "argocd_cluster-secret" {
  triggers_replace = [filesha256("${path.root}/argocd/cluster-secret.yaml"), module.eks.cluster_arn]

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name} && CLUSTER_ARN='${module.eks.cluster_arn}' CLUSTER_CA='${module.eks.cluster_certificate_authority_data}' envsubst < ${path.root}/argocd/cluster-secret.yaml | kubectl apply -f -"
  }

  depends_on = [module.argocd_capability, terraform_data.kubeconfig]
}

resource "terraform_data" "argocd_application" {
  triggers_replace = [filesha256("${path.root}/argocd/application.yaml"), module.eks.cluster_arn]

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name} && CLUSTER_ARN='${module.eks.cluster_arn}' envsubst < ${path.root}/argocd/application.yaml | kubectl apply -f -"
  }

  depends_on = [module.argocd_capability, terraform_data.kubeconfig, terraform_data.argocd_cluster-secret]
}