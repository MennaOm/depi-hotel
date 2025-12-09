resource "kubectl_manifest" "pod_security" {
  yaml_body = file("${path.module}/k8s/pod-security.yaml")
}

resource "kubectl_manifest" "network_policies" {
  yaml_body = file("${path.module}/k8s/network-policies.yaml")
}

resource "kubectl_manifest" "resource_quotas" {
  yaml_body = file("${path.module}/k8s/resource-quotas.yaml")
}
