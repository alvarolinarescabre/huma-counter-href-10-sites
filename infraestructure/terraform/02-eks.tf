module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.cluster_name
  kubernetes_version = local.cluster_version

  endpoint_public_access  = true
  endpoint_private_access = true

  enable_cluster_creator_admin_permissions = false

  access_entries = {
    admin = {
      principal_arn = "arn:aws:iam::312910855403:user/admin"
      type          = "STANDARD"

      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  tags = {
    "Environment" = "dev"
    "Project"     = "eks-argocd"
  }

}

################################################################################
# EKS Access Entry - CodeBuild Role
################################################################################

resource "aws_eks_access_entry" "codebuild" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.codebuild_app.arn
  type          = "STANDARD"

  depends_on = [module.eks]
}

resource "aws_eks_access_policy_association" "codebuild_cluster_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.codebuild_app.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.codebuild]
}

################################################################################
# EKS Access Entry - ArgoCD Role
################################################################################

/*
  The ArgoCD capability module creates an IAM role for ArgoCD, but child-module
  resources cannot be referenced directly from root module configuration. To
  support environments where you want EKS access for that IAM role, provide the
  role ARN via the variable `argocd_role_arn` (e.g. from `terraform state show
  module.argocd_capability.aws_iam_role.this[0]`), then the resources below will
  be created. If `argocd_role_arn` is empty the resources are skipped.
*/

resource "aws_eks_access_entry" "argocd_role" {
  # Create an EKS access entry for the ArgoCD IAM role if provided via
  # `var.argocd_role_arn`. If you have an IAM role created externally for
  # ArgoCD, pass its ARN in that variable. Otherwise this resource is
  # skipped.
  count = var.argocd_role_arn != "" ? 1 : 0

  cluster_name = module.eks.cluster_name
  principal_arn = var.argocd_role_arn
  type          = "STANDARD"

  depends_on = [module.eks]
}

resource "aws_eks_access_policy_association" "argocd_cluster_admin" {
  count = var.argocd_role_arn != "" ? 1 : 0
  cluster_name = module.eks.cluster_name
  principal_arn = var.argocd_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.argocd_role]
}