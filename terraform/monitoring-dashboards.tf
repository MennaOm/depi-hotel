# Custom Dashboard ConfigMap for Application Monitoring
resource "kubernetes_config_map" "grafana_dashboards" {
  metadata {
    name      = "custom-dashboards"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "application-overview.json" = jsonencode({
      "dashboard" = {
        "title"   = "MERN Application Overview"
        "uid"     = "mern-app-overview"
        "version" = 1
        "panels" = [
          {
            "id"    = 1
            "title" = "Pod Status"
            "type"  = "stat"
            "targets" = [
              {
                "expr" = "count(kube_pod_info{namespace=\"${var.app_namespace}\"})"
              }
            ]
            "gridPos" = {
              "h" = 4
              "w" = 6
              "x" = 0
              "y" = 0
            }
          },
          {
            "id"    = 2
            "title" = "CPU Usage by Pod"
            "type"  = "graph"
            "targets" = [
              {
                "expr" = "sum(rate(container_cpu_usage_seconds_total{namespace=\"${var.app_namespace}\"}[5m])) by (pod)"
              }
            ]
            "gridPos" = {
              "h" = 8
              "w" = 12
              "x" = 0
              "y" = 4
            }
          },
          {
            "id"    = 3
            "title" = "Memory Usage by Pod"
            "type"  = "graph"
            "targets" = [
              {
                "expr" = "sum(container_memory_usage_bytes{namespace=\"${var.app_namespace}\"}) by (pod)"
              }
            ]
            "gridPos" = {
              "h" = 8
              "w" = 12
              "x" = 12
              "y" = 4
            }
          },
          {
            "id"    = 4
            "title" = "Pod Restarts"
            "type"  = "graph"
            "targets" = [
              {
                "expr" = "sum(rate(kube_pod_container_status_restarts_total{namespace=\"${var.app_namespace}\"}[5m])) by (pod)"
              }
            ]
            "gridPos" = {
              "h" = 6
              "w" = 12
              "x" = 0
              "y" = 12
            }
          },
          {
            "id"    = 5
            "title" = "Network Traffic"
            "type"  = "graph"
            "targets" = [
              {
                "expr" = "sum(rate(container_network_receive_bytes_total{namespace=\"${var.app_namespace}\"}[5m])) by (pod)"
              }
            ]
            "gridPos" = {
              "h" = 6
              "w" = 12
              "x" = 12
              "y" = 12
            }
          }
        ]
      }
    })
    
    "mongodb-dashboard.json" = jsonencode({
      "dashboard" = {
        "title"   = "MongoDB Metrics"
        "uid"     = "mongodb-metrics"
        "version" = 1
        "panels" = [
          {
            "id"    = 1
            "title" = "MongoDB Connections"
            "type"  = "graph"
            "targets" = [
              {
                "expr" = "mongodb_connections{state=\"current\"}"
              }
            ]
            "gridPos" = {
              "h" = 8
              "w" = 12
              "x" = 0
              "y" = 0
            }
          },
          {
            "id"    = 2
            "title" = "MongoDB Operations"
            "type"  = "graph"
            "targets" = [
              {
                "expr" = "rate(mongodb_op_counters_total[5m])"
              }
            ]
            "gridPos" = {
              "h" = 8
              "w" = 12
              "x" = 12
              "y" = 0
            }
          },
          {
            "id"    = 3
            "title" = "MongoDB Memory Usage"
            "type"  = "graph"
            "targets" = [
              {
                "expr" = "mongodb_memory{type=\"resident\"}"
              }
            ]
            "gridPos" = {
              "h" = 8
              "w" = 12
              "x" = 0
              "y" = 8
            }
          },
          {
            "id"    = 4
            "title" = "MongoDB Query Executor"
            "type"  = "graph"
            "targets" = [
              {
                "expr" = "rate(mongodb_mongod_metrics_query_executor_total[5m])"
              }
            ]
            "gridPos" = {
              "h" = 8
              "w" = 12
              "x" = 12
              "y" = 8
            }
          }
        ]
      }
    })
  }

  depends_on = [helm_release.prometheus]
}
