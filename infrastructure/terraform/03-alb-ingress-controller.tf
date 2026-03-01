resource "kubectl_manifest" "alb_ingress_class" {
  yaml_body = file("${path.root}/alb-ingress-controller/alb-ingress-class.yaml")

  depends_on = [module.eks]
}

resource "kubectl_manifest" "alb_ingress_classparams" {
  yaml_body = file("${path.root}/alb-ingress-controller/alb-ingress-classparams.yaml")

  depends_on = [kubectl_manifest.alb_ingress_class]
}