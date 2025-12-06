# AWS Configuration
aws_region = "us-east-1"
project_name = "hotel-booking"
environment = "dev"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# EKS Configuration
kubernetes_version = "1.28"
node_instance_types = ["t3.small"]
desired_node_count = 3
min_node_count = 2
max_node_count = 5

# Application Configuration
app_namespace = "hotel-app"

# Docker Images from Docker Hub
backend_image = "marvelhelmy/hotel-server:latest"
frontend_image = "marvelhelmy/hotel-client:latest"
mongodb_image = "mongo:7.0"

# Application Settings
mongodb_database = "hotel_booking"
backend_replicas = 1 
frontend_replicas = 1 

#Grafana Acess
grafana_admin_password = "YourSecurePassword123!"
