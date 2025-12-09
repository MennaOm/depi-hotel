variable "enable_k8s_providers" {
  type    = bool
  default = false
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "hotel-booking"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "node_instance_types" {
  description = "Node instance types"
  type        = list(string)
  default     = ["t3.micro", "t3.small", "t2.micro"]
}

variable "desired_node_count" {
  type    = number
  default = 2
}

variable "min_node_count" {
  type    = number
  default = 1
}

variable "max_node_count" {
  type    = number
  default = 4
}

variable "app_namespace" {
  type    = string
  default = "hotel-app"
}

variable "mongodb_image" {
  type    = string
  default = "mongo:7.0"
}

variable "backend_image" {
  description = "Backend Docker image"
  type        = string
}

variable "frontend_image" {
  description = "Frontend Docker image"
  type        = string
}

variable "mongodb_database" {
  type    = string
  default = "hotel_booking"
}

variable "mongodb_root_password" {
  type      = string
  sensitive = true
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "backend_replicas" {
  type    = number
  default = 2
}

variable "frontend_replicas" {
  type    = number
  default = 2
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
}

variable "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  type        = string
}

variable "cluster_ca" {
  description = "Cluster certificate authority (base64 encoded)"
  type        = string
}

variable "cluster_token" {
  description = "Authentication token for Kubernetes cluster"
  type        = string
}
