# Backend ConfigMap
resource "kubernetes_config_map" "backend" {
  metadata {
    name      = "backend-config"
    namespace = var.app_namespace
  }

  data = {
    NODE_ENV      = var.environment
    PORT          = "5000"
    MONGODB_URI   = "mongodb://admin:${var.mongodb_root_password}@mongodb.${var.app_namespace}.svc.cluster.local:27017/${var.mongodb_database}?authSource=admin"
    DATABASE_NAME = var.mongodb_database
  }
  
  depends_on = [kubernetes_namespace.app]
}

# Backend Secret
resource "kubernetes_secret" "backend" {
  metadata {
    name      = "backend-secret"
    namespace = var.app_namespace
  }

  data = {
    jwt-secret = base64encode(var.jwt_secret)
  }

  type = "Opaque"
  
  depends_on = [kubernetes_namespace.app]
}

# Backend Deployment
resource "kubernetes_deployment" "backend" {
  metadata {
    name      = "backend"
    namespace = var.app_namespace
    labels = {
      app = "backend"
    }
  }

  spec {
    replicas = var.backend_replicas

    selector {
      match_labels = {
        app = "backend"
      }
    }

    template {
      metadata {
        labels = {
          app = "backend"
        }
      }

      spec {
        container {
          name              = "backend"
          image             = var.backend_image
          image_pull_policy = "Always"

          port {
            container_port = 5000
            name           = "http"
          }

          env {
            name = "NODE_ENV"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.backend.metadata[0].name
                key  = "NODE_ENV"
              }
            }
          }

          env {
            name = "PORT"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.backend.metadata[0].name
                key  = "PORT"
              }
            }
          }

          env {
            name = "MONGODB_URI"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.backend.metadata[0].name
                key  = "MONGODB_URI"
              }
            }
          }

          env {
            name = "JWT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.backend.metadata[0].name
                key  = "jwt-secret"
              }
            }
          }

          resources {
            requests = {
              memory = "128Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "256Mi"
              cpu    = "250m"
            }
          }

          liveness_probe {
            tcp_socket {
              port = 5000
            }
            initial_delay_seconds = 60
            period_seconds        = 10
          }

          readiness_probe {
            tcp_socket {
              port = 5000
            }
            initial_delay_seconds = 30
            period_seconds        = 5
          }
        }
      }
    }
  }

  wait_for_rollout = false

  timeouts {
    create = "15m"
    update = "10m"
    delete = "5m"
  }

  depends_on = [
    kubernetes_namespace.app,
    kubernetes_service.mongodb,
    kubernetes_config_map.backend,
    kubernetes_secret.backend
  ]

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      spec[0].template[0].metadata[0].annotations
    ]
  }
}

# Backend Service
resource "kubernetes_service" "backend" {
  metadata {
    name      = "backend"
    namespace = var.app_namespace
    labels = {
      app = "backend"
    }
  }

  spec {
    selector = {
      app = "backend"
    }

    port {
      port        = 5000
      target_port = 5000
      protocol    = "TCP"
      name        = "http"
    }

    type = "ClusterIP"
  }
  
  depends_on = [kubernetes_deployment.backend]
}
