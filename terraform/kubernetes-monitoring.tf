# Monitoring Namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
  depends_on = [null_resource.wait_for_cluster]
}

# Prometheus using Helm
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "55.0.0"
  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          retention = "15d"
          resources = {
            requests = {
              cpu    = "200m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "2Gi"
            }
          }
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = kubernetes_storage_class.ebs_sc.metadata[0].name
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "20Gi"
                  }
                }
              }
            }
          }
          # Service monitors for auto-discovery
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
        }
      }
      
      grafana = {
        enabled = true
        adminPassword = var.grafana_admin_password
        persistence = {
          enabled          = true
          storageClassName = kubernetes_storage_class.ebs_sc.metadata[0].name
          size             = "10Gi"
        }
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
        # Default dashboards
        defaultDashboardsEnabled = true
        # Additional dashboards
        dashboardProviders = {
          "dashboardproviders.yaml" = {
            apiVersion = 1
            providers = [
              {
                name            = "default"
                orgId           = 1
                folder          = ""
                type            = "file"
                disableDeletion = false
                editable        = true
                options = {
                  path = "/var/lib/grafana/dashboards/default"
                }
              }
            ]
          }
        }
        # Pre-configured dashboards
        dashboards = {
          default = {
            kubernetes-cluster = {
              gnetId     = 7249
              revision   = 1
              datasource = "Prometheus"
            }
            kubernetes-pods = {
              gnetId     = 6417
              revision   = 1
              datasource = "Prometheus"
            }
            node-exporter = {
              gnetId     = 1860
              revision   = 31
              datasource = "Prometheus"
            }
            nginx-ingress = {
              gnetId     = 9614
              revision   = 1
              datasource = "Prometheus"
            }
          }
        }
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
          }
        }
      }
      
      # Alert Manager
      alertmanager = {
        enabled = true
        alertmanagerSpec = {
          resources = {
            requests = {
              cpu    = "50m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "256Mi"
            }
          }
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = kubernetes_storage_class.ebs_sc.metadata[0].name
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "5Gi"
                  }
                }
              }
            }
          }
        }
      }
      
      # Node Exporter
      nodeExporter = {
        enabled = true
      }
      
      # Kube State Metrics
      kubeStateMetrics = {
        enabled = true
      }
    })
  ]
  timeout = 900
  wait    = true
  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_storage_class.ebs_sc,
    null_resource.wait_for_storage_class
  ]
}

# Wait for Prometheus Operator CRDs to be ready
resource "null_resource" "wait_for_prometheus_crds" {
  provisioner "local-exec" {
    command     = "Write-Host 'Waiting for Prometheus CRDs...'; Start-Sleep -Seconds 60"
    interpreter = ["PowerShell", "-Command"]
  }
  depends_on = [helm_release.prometheus]
}

# ServiceMonitor for Backend
resource "null_resource" "backend_service_monitor" {
  provisioner "local-exec" {
    command = <<-EOT
      $yaml = @"
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: backend-monitor
  namespace: ${var.app_namespace}
  labels:
    app: backend
spec:
  selector:
    matchLabels:
      app: backend
  endpoints:
  - port: http
    interval: 30s
    path: /metrics
"@
      $yaml | kubectl apply -f -
    EOT
    interpreter = ["PowerShell", "-Command"]
  }
  depends_on = [
    null_resource.wait_for_prometheus_crds,
    kubernetes_service.backend
  ]
}

# ServiceMonitor for Frontend
resource "null_resource" "frontend_service_monitor" {
  provisioner "local-exec" {
    command = <<-EOT
      $yaml = @"
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: frontend-monitor
  namespace: ${var.app_namespace}
  labels:
    app: frontend
spec:
  selector:
    matchLabels:
      app: frontend
  endpoints:
  - port: http
    interval: 30s
"@
      $yaml | kubectl apply -f -
    EOT
    interpreter = ["PowerShell", "-Command"]
  }
  depends_on = [
    null_resource.wait_for_prometheus_crds,
    kubernetes_service.frontend
  ]
}

# ServiceMonitor for MongoDB
resource "null_resource" "mongodb_service_monitor" {
  provisioner "local-exec" {
    command = <<-EOT
      $yaml = @"
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: mongodb-monitor
  namespace: ${var.app_namespace}
  labels:
    app: mongodb
spec:
  selector:
    matchLabels:
      app: mongodb
  endpoints:
  - port: mongodb
    interval: 30s
"@
      $yaml | kubectl apply -f -
    EOT
    interpreter = ["PowerShell", "-Command"]
  }
  depends_on = [
    null_resource.wait_for_prometheus_crds,
    kubernetes_service.mongodb
  ]
}

# MongoDB Exporter for detailed metrics
resource "kubernetes_deployment" "mongodb_exporter" {
  metadata {
    name      = "mongodb-exporter"
    namespace = var.app_namespace
    labels = {
      app = "mongodb-exporter"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "mongodb-exporter"
      }
    }
    template {
      metadata {
        labels = {
          app = "mongodb-exporter"
        }
      }
      spec {
        container {
          name  = "mongodb-exporter"
          image = "percona/mongodb_exporter:0.40"
          port {
            container_port = 9216
            name           = "metrics"
          }
          env {
            name  = "MONGODB_URI"
            value = "mongodb://admin:${var.mongodb_root_password}@mongodb.${var.app_namespace}.svc.cluster.local:27017/admin"
          }
          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_namespace.app,
    kubernetes_service.mongodb
  ]
}

resource "kubernetes_service" "mongodb_exporter" {
  metadata {
    name      = "mongodb-exporter"
    namespace = var.app_namespace
    labels = {
      app = "mongodb-exporter"
    }
  }
  spec {
    selector = {
      app = "mongodb-exporter"
    }
    port {
      port        = 9216
      target_port = 9216
      name        = "metrics"
    }
    type = "ClusterIP"
  }
  depends_on = [kubernetes_deployment.mongodb_exporter]
}

# ServiceMonitor for MongoDB Exporter
resource "null_resource" "mongodb_exporter_service_monitor" {
  provisioner "local-exec" {
    command = <<-EOT
      $yaml = @"
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: mongodb-exporter-monitor
  namespace: ${var.app_namespace}
  labels:
    app: mongodb-exporter
spec:
  selector:
    matchLabels:
      app: mongodb-exporter
  endpoints:
  - port: metrics
    interval: 30s
"@
      $yaml | kubectl apply -f -
    EOT
    interpreter = ["PowerShell", "-Command"]
  }
  depends_on = [
    null_resource.wait_for_prometheus_crds,
    kubernetes_service.mongodb_exporter
  ]
}

# PrometheusRule for custom alerts
resource "null_resource" "custom_alerts" {
  provisioner "local-exec" {
    command = <<-EOT
      $yaml = @"
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: custom-alerts
  namespace: ${kubernetes_namespace.monitoring.metadata[0].name}
  labels:
    prometheus: kube-prometheus
spec:
  groups:
  - name: application-alerts
    rules:
    - alert: PodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total[5m]) > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Pod {{ `$labels.pod }} is crash looping"
        description: "Pod {{ `$labels.pod }} in namespace {{ `$labels.namespace }} has restarted {{ `$value }} times in the last 5 minutes"
    - alert: HighMemoryUsage
      expr: (container_memory_usage_bytes / container_spec_memory_limit_bytes) > 0.9
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage detected"
        description: "Container {{ `$labels.container }} in pod {{ `$labels.pod }} is using {{ `$value }} of memory limit"
    - alert: HighCPUUsage
      expr: (rate(container_cpu_usage_seconds_total[5m]) / container_spec_cpu_quota * 100) > 90
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High CPU usage detected"
        description: "Container {{ `$labels.container }} in pod {{ `$labels.pod }} is using {{ `$value }}% of CPU limit"
    - alert: PodNotReady
      expr: kube_pod_status_phase{phase!="Running"} == 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Pod not ready"
        description: "Pod {{ `$labels.pod }} in namespace {{ `$labels.namespace }} has been in {{ `$labels.phase }} phase for more than 5 minutes"
    - alert: MongoDBDown
      expr: up{job="mongodb-exporter"} == 0
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "MongoDB is down"
        description: "MongoDB exporter has been down for more than 2 minutes"
    - alert: NodeDiskPressure
      expr: kube_node_status_condition{condition="DiskPressure",status="true"} == 1
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Node disk pressure"
        description: "Node {{ `$labels.node }} has disk pressure"
"@
      $yaml | kubectl apply -f -
    EOT
    interpreter = ["PowerShell", "-Command"]
  }
  depends_on = [null_resource.wait_for_prometheus_crds]
}

# Output Grafana URL
output "grafana_url" {
  description = "Grafana LoadBalancer URL"
  value       = "Get URL with: kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "grafana_admin_user" {
  description = "Grafana admin username"
  value       = "admin"
}

output "prometheus_url" {
  description = "Prometheus service URL (internal)"
  value       = "http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090"
}
