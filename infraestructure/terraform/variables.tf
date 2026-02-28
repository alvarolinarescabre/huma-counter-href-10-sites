variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "sso_admin_email" {
  description = "Email of the SSO admin user for ArgoCD"
  type        = string
  default     = "alvarolinarescabre@gmail.com"
}

variable "tf_action" {
  description = "Terraform action to perform: apply or destroy"
  type        = string
  default     = "apply"

  validation {
    condition     = contains(["apply", "destroy"], var.tf_action)
    error_message = "tf_action must be 'apply' or 'destroy'."
  }
}

variable "github_repo" {
  description = "GitHub repository (owner/repo)"
  type        = string
  default     = "alvarolinarescabre/eks-argocd"
}

variable "github_branch" {
  description = "GitHub branch to track"
  type        = string
  default     = "main"
}

variable "approval_email" {
  description = "Email for manual approval notifications (optional)"
  type        = string
  default     = ""
}

variable "app_github_repo" {
  description = "GitHub repository for the app (owner/repo)"
  type        = string
  default     = "alvarolinarescabre/huma-counter-href-10-sites"
}

## Removed `github_token` variable - repository is public and no token is required

variable "argocd_manifests_repo" {
  description = "GitHub repository for ArgoCD K8s manifests (owner/repo)"
  type        = string
  default     = "alvarolinarescabre/huma-counter-href-10-sites"
}

variable "argocd_role_arn" {
  description = "(Optional) IAM role ARN created by argocd_capability module to grant EKS access to ArgoCD"
  type        = string
  default     = ""
}

variable "deploy_buildspec_name" {
  description = "Optional buildspec filename for the deploy CodeBuild project; if empty the project will use default buildspec.yml from source."
  type        = string
  default     = ""
}