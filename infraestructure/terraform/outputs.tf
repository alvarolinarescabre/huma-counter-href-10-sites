output "instructions" {
  value = <<-EOT
Update Kubeconfig:
------------------
Run this command to update ~/.kube/config file: 'aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}'


To Login ArgoCD:
----------------
1) ArgoCD Server URL: ${module.argocd_capability.argocd_server_url}
2) Login via AWS IAM Identity Center (SSO)
3) SSO Start URL: Check your email (${var.sso_admin_email}) for the SSO invitation

SSO Details:
------------
SSO Instance ARN: ${local.sso_instance_arn}
Admin Group: ArgoCD-Admins

FastAPI Hit 10 App:
-------------------
After deploy on ArgoCD, Run this command: 'kubectl get ingress' and uses the ADDRESS from 'fastapi-app-get-href-from-10-websites'

ECR Repository:
---------------
ECR URI: ${aws_ecr_repository.app.repository_url}

To Destroy:
-----------
Do this steps to destroy all:

1) terraform destroy

EOT
}
