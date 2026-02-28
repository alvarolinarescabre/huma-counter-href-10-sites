################################################################################
# Kubeconfig setup (runs after EKS cluster is ready)
################################################################################

resource "time_sleep" "wait_for_cluster" {
  depends_on      = [module.eks, aws_eks_access_entry.codebuild, aws_eks_access_policy_association.codebuild_cluster_admin]
  create_duration = "30s"
}

resource "terraform_data" "kubeconfig" {
  triggers_replace = [module.eks.cluster_endpoint]

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
  }

  depends_on = [time_sleep.wait_for_cluster]
}

################################################################################
# ALB Ingress Controller - IngressClass & IngressClassParams
################################################################################

resource "terraform_data" "alb_ingress_class" {
  triggers_replace = [filesha256("${path.root}/alb-ingress-controller/alb-ingress-class.yaml")]

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name} && kubectl apply -f ${path.root}/alb-ingress-controller/alb-ingress-class.yaml"
  }

  depends_on = [terraform_data.kubeconfig]
}

resource "terraform_data" "alb_ingress_class_params" {
  triggers_replace = [filesha256("${path.root}/alb-ingress-controller/alb-ingress-classparms.yaml")]

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name} && kubectl apply -f ${path.root}/alb-ingress-controller/alb-ingress-classparms.yaml"
  }

  depends_on = [terraform_data.alb_ingress_class]
}
