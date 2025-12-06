.PHONY: help init plan apply destroy clean validate fmt configure-kubectl logs status port-forward

# Variables
CLUSTER_NAME ?= mern-ecommerce
REGION ?= us-east-1
NAMESPACE ?= mern-app

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize Terraform
	terraform init

validate: ## Validate Terraform configuration
	terraform validate

fmt: ## Format Terraform files
	terraform fmt -recursive

plan: ## Show Terraform execution plan
	terraform plan

apply: ## Apply Terraform configuration
	terraform apply -auto-approve

destroy: ## Destroy all Terraform resources
	@echo "WARNING: This will destroy all resources!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		terraform destroy; \
	fi

configure-kubectl: ## Configure kubectl for EKS cluster
	aws eks update-kubeconfig --region $(REGION) --name $(CLUSTER_NAME)

status: ## Show cluster and application status
	@echo "=== Cluster Info ==="
	kubectl cluster-info
	@echo "\n=== Nodes ==="
	kubectl get nodes
	@echo "\n=== Pods ==="
	kubectl get pods -n $(NAMESPACE)
	@echo "\n=== Services ==="
	kubectl get svc -n $(NAMESPACE)
	@echo "\n=== Ingress ==="
	kubectl get ingress -n $(NAMESPACE)

logs: ## Show logs for all backend pods
	kubectl logs -l app=backend -n $(NAMESPACE) --tail=100 -f

logs-frontend: ## Show logs for frontend pods
	kubectl logs -l app=frontend -n $(NAMESPACE) --tail=100 -f

logs-mongodb: ## Show logs for MongoDB
	kubectl logs mongodb-0 -n $(NAMESPACE) --tail=100 -f

port-forward: ## Forward ports for local access
	@echo "Forwarding frontend to localhost:3000"
	@echo "Forwarding backend to localhost:5000"
	kubectl port-forward -n $(NAMESPACE) svc/frontend 3000:80 & \
	kubectl port-forward -n $(NAMESPACE) svc/backend 5000:5000

shell-backend: ## Open shell in backend pod
	kubectl exec -it -n $(NAMESPACE) $$(kubectl get pod -n $(NAMESPACE) -l app=backend -o jsonpath='{.items[0].metadata.name}') -- /bin/sh

shell-mongodb: ## Open MongoDB shell
	kubectl exec -it mongodb-0 -n $(NAMESPACE) -- mongosh -u admin -p

scale-backend: ## Scale backend deployment (usage: make scale-backend REPLICAS=3)
	kubectl scale deployment backend --replicas=$(REPLICAS) -n $(NAMESPACE)

scale-frontend: ## Scale frontend deployment (usage: make scale-frontend REPLICAS=3)
	kubectl scale deployment frontend --replicas=$(REPLICAS) -n $(NAMESPACE)

restart-backend: ## Restart backend deployment
	kubectl rollout restart deployment/backend -n $(NAMESPACE)

restart-frontend: ## Restart frontend deployment
	kubectl rollout restart deployment/frontend -n $(NAMESPACE)

get-url: ## Get application URLs
	@echo "=== Frontend LoadBalancer URL ==="
	@kubectl get svc frontend -n $(NAMESPACE) -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
	@echo "\n=== Ingress URL ==="
	@kubectl get ingress app-ingress -n $(NAMESPACE) -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
	@echo ""

describe-pods: ## Describe all pods
	kubectl describe pods -n $(NAMESPACE)

events: ## Show recent events
	kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp'

top: ## Show resource usage
	@echo "=== Node Resources ==="
	kubectl top nodes
	@echo "\n=== Pod Resources ==="
	kubectl top pods -n $(NAMESPACE)

clean: ## Clean Terraform files
	rm -rf .terraform/
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate*

outputs: ## Show Terraform outputs
	terraform output
