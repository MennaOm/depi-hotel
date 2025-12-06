output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "frontend_url" {
  description = "Frontend LoadBalancer URL"
  value       = "Wait for LoadBalancer provisioning, then run: kubectl get svc frontend -n ${var.app_namespace}"
}

output "ingress_url" {
  description = "Application Ingress URL (after ALB is provisioned)"
  value       = "Check ingress status with: kubectl get ingress -n ${var.app_namespace}"
}

output "namespace" {
  description = "Kubernetes namespace"
  value       = kubernetes_namespace.app.metadata[0].name
}

output "get_pods" {
  description = "Command to get pods"
  value       = "kubectl get pods -n ${var.app_namespace}"
}
