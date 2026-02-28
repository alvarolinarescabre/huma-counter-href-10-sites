################################################################################
# Identity Store - User
################################################################################

resource "aws_identitystore_user" "admin" {
  identity_store_id = local.identity_store_id

  # depends_on eliminado porque aws_codepipeline.this ya no existe

  display_name = "ArgoCD Admin"
  user_name    = var.sso_admin_email

  name {
    given_name  = "ArgoCD"
    family_name = "Admin"
  }

  emails {
    value   = var.sso_admin_email
    primary = true
  }
}

################################################################################
# Identity Store - Group
################################################################################

resource "aws_identitystore_group" "argocd_admins" {
  identity_store_id = local.identity_store_id
  display_name      = "ArgoCD-Admins"
  description       = "Admin group for ArgoCD EKS Capability"
}

resource "aws_identitystore_group_membership" "admin" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.argocd_admins.group_id
  member_id         = aws_identitystore_user.admin.user_id
}
