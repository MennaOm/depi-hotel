resource "kubernetes_manifest" "backend_hpa" {
  provider = kubernetes-alpha
  manifest = yamldecode(file("${path.module}/k8s/backend-hpa.yaml"))
}
