output "kubeconfig_command" {
  description = "Command to update local kubeconfig for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "argocd_server_url" {
  description = "ArgoCD server URL"
  value       = module.argocd_capability.argocd_server_url
}

output "argocd_login_instructions" {
  description = "How to login to ArgoCD"
  value = <<-EOT
1) URL: ${module.argocd_capability.argocd_server_url}
2) Login via AWS IAM Identity Center (SSO)
3) Check your email (${var.sso_admin_email}) for the SSO invitation and ArgoCD admin group membership
EOT
}

output "ecr_repository_uri" {
  description = "ECR repository URI for the app image"
  value       = aws_ecr_repository.app.repository_url
}

output "codepipeline_name" {
  description = "CodePipeline name for app CI/CD"
  value       = aws_codepipeline.app.name
}

output "codebuild_app_build_project" {
  description = "CodeBuild project that builds the Docker image"
  value       = aws_codebuild_project.app_build.name
}

output "codebuild_app_deploy_project" {
  description = "CodeBuild project used by the Deploy stage to update ArgoCD manifests"
  value       = aws_codebuild_project.app_deploy.name
}

output "artifact_bucket" {
  description = "S3 bucket used for pipeline artifacts"
  value       = aws_s3_bucket.app_pipeline_artifacts.bucket
}

output "codestar_connection_arn" {
  description = "CodeStar Connections ARN used for GitHub source"
  value       = aws_codestarconnections_connection.github.arn
}

output "sso_instance_arn" {
  description = "SSO (Identity Center) instance ARN used for ArgoCD SSO"
  value       = local.sso_instance_arn
}

output "notes" {
  description = "Helpful notes"
  value = <<-EOT
- After making changes to manifests, the Deploy stage will push to the ArgoCD manifests repo branch and ArgoCD will sync the app.
- To destroy everything: run 'terraform destroy' in this folder.
EOT
}
