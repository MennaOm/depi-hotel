# Install AWS Load Balancer Controller using Helm
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.6.2"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_load_balancer_controller.arn
  }

  timeout = 600
  wait    = true

  depends_on = [
    module.eks,
    kubernetes_namespace.app,
    null_resource.wait_for_cluster,
    aws_iam_role_policy_attachment.aws_load_balancer_controller
  ]
}

# Wait for ALB controller to be ready
resource "null_resource" "wait_for_alb_controller" {
  provisioner "local-exec" {
    command = "powershell -Command \"Write-Host 'Waiting for ALB controller...'; Start-Sleep -Seconds 30\""
  }

  depends_on = [helm_release.aws_load_balancer_controller]
}

# Ingress for the application
resource "kubernetes_ingress_v1" "app" {
  metadata {
    name      = "app-ingress"
    namespace = kubernetes_namespace.app.metadata[0].name
    annotations = {
      "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\": 80}]"
    }
  }
  
  spec {
    ingress_class_name = "alb"
    
    rule {
      http {
        path {
          path      = "/api"      # Remove /* - just /api
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.backend.metadata[0].name
              port {
                number = 5000
              }
            }
          }
        }
        path {
          path      = "/"         # Remove /* - just /
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.frontend.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
  
  depends_on = [
    null_resource.wait_for_alb_controller,
    kubernetes_service.frontend,
    kubernetes_service.backend
  ]
}
