resource "helm_release" "argocd" {
  name = "argocd"

  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "9.4.5"
  namespace        = "argocd"
  create_namespace = true
  cleanup_on_fail  = true
  timeout          = 300

  values = [file("${path.root}/helm/argocd.yaml")]

  depends_on = [kubectl_manifest.alb_ingress_classparams]
}

resource "kubectl_manifest" "argocd_application" {
  yaml_body = file("${path.root}/argocd/application.yaml")

  depends_on = [helm_release.argocd]
}