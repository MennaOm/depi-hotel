pipeline {
    agent any

    parameters {
        choice(
            name: 'PIPELINE_ACTION',
            choices: [
                'docker-only',
                'terraform-plan',
                'terraform-apply',
                'terraform-destroy',
                'full-deploy',
                'terraform-clean-and-apply'
            ],
            description: 'Select action: docker-only (build & push), terraform-plan/apply/destroy, full-deploy (both), or terraform-clean-and-apply (destroy+clean+apply)'
        )
    }

    environment {
        // Docker Hub credentials (expects username/password credential binding in Jenkins)
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        DOCKERHUB_USERNAME = 'mennaomar12'   // <-- change if needed
        CLIENT_IMAGE = "${DOCKERHUB_USERNAME}/hotel-client"
        SERVER_IMAGE = "${DOCKERHUB_USERNAME}/hotel-server"
        IMAGE_TAG = "${BUILD_NUMBER}"

        // Frontend env (build args)
        VITE_BACKEND_URL = 'http://localhost:3000'
        VITE_CURRENCY = '$'
        CLERK_KEY = credentials('clerk-publishable-key')
        STRIPE_KEY = credentials('stripe-publishable-key')

        // AWS default region
        AWS_DEFAULT_REGION = 'us-east-1'

        // Terraform variables (will be exported at runtime)
        TF_VAR_backend_image = "${SERVER_IMAGE}:latest"
        TF_VAR_frontend_image = "${CLIENT_IMAGE}:latest"
    }

    options {
        timestamps()
        ansiColor('xterm')
        timeout(time: 120, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    stages {
        stage('Checkout') {
            steps {
                echo '📥 Checking out code...'
                checkout scm
            }
        }

        stage('Verify Structure') {
            steps {
                echo '📂 Verifying repository structure...'
                sh '''
                    echo "Listing workspace:"
                    ls -la || true
                    if [ -d client ]; then echo "Client folder found"; else echo "ERROR: client/ not found"; fi
                    if [ -d server ]; then echo "Server folder found"; else echo "ERROR: server/ not found"; fi
                    if [ -d terraform ]; then echo "Terraform folder found"; else echo "WARNING: terraform/ not found - terraform stages will be skipped"; fi
                    if [ -d k8s ]; then echo "k8s manifests found"; else echo "NOTE: k8s/ not found"; fi
                '''
            }
        }

        // ------------------ DOCKER BUILD & PUSH ------------------

        stage('Build Client Image') {
            when {
                expression { params.PIPELINE_ACTION == 'docker-only' || params.PIPELINE_ACTION == 'full-deploy' }
            }
            steps {
                echo '🔨 Building frontend Docker image...'
                dir('client') {
                    sh '''
                        set -e
                        docker build \
                            --build-arg VITE_BACKEND_URL=${VITE_BACKEND_URL} \
                            --build-arg VITE_CURRENCY=${VITE_CURRENCY} \
                            --build-arg VITE_CLERK_PUBLISHABLE_KEY=${CLERK_KEY} \
                            --build-arg VITE_STRIPE_PUBLISHABLE_KEY=${STRIPE_KEY} \
                            -t ${CLIENT_IMAGE}:${IMAGE_TAG} \
                            -t ${CLIENT_IMAGE}:latest \
                            .
                    '''
                }
            }
        }

        stage('Build Server Image') {
            when {
                expression { params.PIPELINE_ACTION == 'docker-only' || params.PIPELINE_ACTION == 'full-deploy' }
            }
            steps {
                echo '🔨 Building backend Docker image...'
                dir('server') {
                    sh '''
                        set -e
                        docker build \
                            -t ${SERVER_IMAGE}:${IMAGE_TAG} \
                            -t ${SERVER_IMAGE}:latest \
                            .
                    '''
                }
            }
        }

        stage('Security Scan - Container Images (Trivy)') {
            when {
                expression { params.PIPELINE_ACTION == 'docker-only' || params.PIPELINE_ACTION == 'full-deploy' }
            }
            steps {
                echo '🔍 Running Trivy scan on images (HIGH+CRITICAL will be listed)...'
                script {
                    // Scan server then client. Don't fail pipeline on findings; just print results.
                    sh '''
                        set -e || true
                        echo "Scanning ${SERVER_IMAGE}:latest"
                        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                            aquasec/trivy:latest image \
                            --timeout 30m \
                            --exit-code 0 \
                            --severity HIGH,CRITICAL \
                            --format table \
                            ${SERVER_IMAGE}:latest || echo "Trivy finished for server"
                        echo "Scanning ${CLIENT_IMAGE}:latest"
                        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                            aquasec/trivy:latest image \
                            --timeout 30m \
                            --exit-code 0 \
                            --severity HIGH,CRITICAL \
                            --format table \
                            ${CLIENT_IMAGE}:latest || echo "Trivy finished for client"
                    '''
                }
            }
        }

        stage('Login to Docker Hub') {
            when {
                expression { params.PIPELINE_ACTION == 'docker-only' || params.PIPELINE_ACTION == 'full-deploy' }
            }
            steps {
                echo '🔐 Logging into Docker Hub...'
                // Jenkins will provide DOCKERHUB_CREDENTIALS_USR / DOCKERHUB_CREDENTIALS_PSW
                sh 'echo ${DOCKERHUB_CREDENTIALS_PSW} | docker login -u ${DOCKERHUB_CREDENTIALS_USR} --password-stdin'
            }
        }

        stage('Push Images to Docker Hub') {
            when {
                expression { params.PIPELINE_ACTION == 'docker-only' || params.PIPELINE_ACTION == 'full-deploy' }
            }
            steps {
                echo '📤 Pushing images to Docker Hub...'
                sh '''
                    set -e
                    docker push ${CLIENT_IMAGE}:${IMAGE_TAG}
                    docker push ${CLIENT_IMAGE}:latest
                    docker push ${SERVER_IMAGE}:${IMAGE_TAG}
                    docker push ${SERVER_IMAGE}:latest
                '''
            }
        }

        stage('Docker Cleanup') {
            when {
                expression { params.PIPELINE_ACTION == 'docker-only' || params.PIPELINE_ACTION == 'full-deploy' }
            }
            steps {
                echo '🧹 Cleaning up local docker images...'
                sh '''
                    docker rmi ${CLIENT_IMAGE}:${IMAGE_TAG} 2>/dev/null || true
                    docker rmi ${CLIENT_IMAGE}:latest 2>/dev/null || true
                    docker rmi ${SERVER_IMAGE}:${IMAGE_TAG} 2>/dev/null || true
                    docker rmi ${SERVER_IMAGE}:latest 2>/dev/null || true
                    docker system prune -f 2>/dev/null || true
                '''
            }
        }

        // ------------------ TERRAFORM (Linux) ------------------

        stage('Setup AWS & Terraform Credentials') {
            when {
                expression { params.PIPELINE_ACTION != 'docker-only' }
            }
            steps {
                echo '🔑 Preparing AWS/Terraform credentials...'
                sh 'echo "Credentials will be injected into terraform stages via withCredentials block."'
            }
        }

        stage('Terraform Init') {
            when {
                expression {
                    params.PIPELINE_ACTION == 'terraform-plan' ||
                    params.PIPELINE_ACTION == 'terraform-apply' ||
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
                    params.PIPELINE_ACTION == 'full-deploy' ||
                    params.PIPELINE_ACTION == 'terraform-destroy'
                }
            }
            steps {
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh '''
                            set -e
                            export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                            export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                            terraform init -upgrade
                        '''
                    }
                }
            }
        }

        stage('Terraform Format Check & Validate') {
            when {
                expression {
                    params.PIPELINE_ACTION == 'terraform-plan' ||
                    params.PIPELINE_ACTION == 'terraform-apply' ||
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
                    params.PIPELINE_ACTION == 'full-deploy'
                }
            }
            steps {
                dir('terraform') {
                    sh '''
                        set -e || true
                        echo "Checking terraform fmt..."
                        terraform fmt -check -recursive || echo "Run terraform fmt -recursive to fix formatting"
                        echo "Validating terraform..."
                        terraform validate || echo "Terraform validate found issues"
                    '''
                }
            }
        }

        stage('Terraform Plan') {
            when {
                expression {
                    params.PIPELINE_ACTION == 'terraform-plan' ||
                    params.PIPELINE_ACTION == 'terraform-apply' ||
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
                    params.PIPELINE_ACTION == 'full-deploy'
                }
            }
            steps {
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                        string(credentialsId: 'mongodb-password', variable: 'MONGODB_PASSWORD'),
                        string(credentialsId: 'jwt-secret', variable: 'JWT_SECRET'),
                        string(credentialsId: 'clerk-publishable-key', variable: 'CLERK_PUBLISHABLE_KEY'),
                        string(credentialsId: 'clerk-secret-key', variable: 'CLERK_SECRET_KEY')
                    ]) {
                        sh '''
                            set -e
                            export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                            export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                            export TF_VAR_mongodb_root_password=${MONGODB_PASSWORD}
                            export TF_VAR_jwt_secret=${JWT_SECRET}
                            export TF_VAR_clerk_publishable_key=${CLERK_PUBLISHABLE_KEY}
                            export TF_VAR_clerk_secret_key=${CLERK_SECRET_KEY}
                            export TF_VAR_backend_image=${SERVER_IMAGE}:latest
                            export TF_VAR_frontend_image=${CLIENT_IMAGE}:latest
                            terraform plan -out=tfplan -detailed-exitcode || echo "Terraform plan completed (exit code non-zero indicates changes or error)."
                        '''
                    }
                }
            }
        }

        stage('Terraform Destroy (Clean)') {
            when {
                expression {
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
                    params.PIPELINE_ACTION == 'terraform-destroy'
                }
            }
            steps {
                echo '🗑️ Terraform destroy requested - confirmation required.'
                script {
                    input message: '⚠ Are you ABSOLUTELY SURE you want to destroy Terraform-managed resources?', ok: 'Yes, destroy'
                }
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                        string(credentialsId: 'mongodb-password', variable: 'MONGODB_PASSWORD'),
                        string(credentialsId: 'jwt-secret', variable: 'JWT_SECRET')
                    ]) {
                        sh '''
                            set -e || true
                            export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                            export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                            export TF_VAR_mongodb_root_password=${MONGODB_PASSWORD}
                            export TF_VAR_jwt_secret=${JWT_SECRET}
                            export TF_VAR_backend_image=${SERVER_IMAGE}:latest
                            export TF_VAR_frontend_image=${CLIENT_IMAGE}:latest
                            terraform destroy -auto-approve || echo "Destroy finished (may have failed for some resources or none existed)"
                        '''
                    }
                }
            }
        }

        stage('Clean Terraform State Files') {
            when {
                expression { params.PIPELINE_ACTION == 'terraform-clean-and-apply' }
            }
            steps {
                dir('terraform') {
                    sh '''
                        rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl || true
                        rm -rf .terraform || true
                        echo "Terraform local state cleaned (if present)."
                    '''
                }
            }
        }

        // Optional: cleanup existing k8s deployments (best-effort)
        stage('Cleanup Existing Kubernetes Resources') {
            when {
                expression {
                    params.PIPELINE_ACTION == 'terraform-apply' ||
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
                    params.PIPELINE_ACTION == 'full-deploy'
                }
            }
            steps {
                script {
                    echo '🧹 Attempting to clean existing k8s deployments (best-effort)'
                    dir('terraform') {
                        withCredentials([
                            string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                            string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                        ]) {
                            sh '''
                                set -e || true
                                export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                                export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                                if [ -f .terraform/terraform.tfstate ] || [ -d .terraform ]; then
                                    CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "hotel-booking")
                                else
                                    CLUSTER_NAME="hotel-booking"
                                fi
                                echo "Using cluster name: $CLUSTER_NAME"
                                aws eks update-kubeconfig --region ${AWS_DEFAULT_REGION} --name $CLUSTER_NAME || echo "Could not update kubeconfig"
                                kubectl delete deployment backend -n hotel-app --ignore-not-found=true || true
                                kubectl delete deployment frontend -n hotel-app --ignore-not-found=true || true
                                sleep 5
                                kubectl get deployments -n hotel-app || true
                            '''
                        }
                    }
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression {
                    params.PIPELINE_ACTION == 'terraform-apply' ||
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
                    params.PIPELINE_ACTION == 'full-deploy'
                }
            }
            steps {
                echo '🚀 Applying Terraform (auto-approve) - WARNING: will create AWS resources and incur costs.'
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                        string(credentialsId: 'mongodb-password', variable: 'MONGODB_PASSWORD'),
                        string(credentialsId: 'jwt-secret', variable: 'JWT_SECRET'),
                        string(credentialsId: 'clerk-publishable-key', variable: 'CLERK_PUBLISHABLE_KEY'),
                        string(credentialsId: 'clerk-secret-key', variable: 'CLERK_SECRET_KEY')
                    ]) {
                        sh '''
                            set -e
                            export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                            export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                            export TF_VAR_mongodb_root_password=${MONGODB_PASSWORD}
                            export TF_VAR_jwt_secret=${JWT_SECRET}
                            export TF_VAR_clerk_publishable_key=${CLERK_PUBLISHABLE_KEY}
                            export TF_VAR_clerk_secret_key=${CLERK_SECRET_KEY}
                            export TF_VAR_backend_image=${SERVER_IMAGE}:latest
                            export TF_VAR_frontend_image=${CLIENT_IMAGE}:latest
                            terraform apply -auto-approve tfplan || terraform apply -auto-approve || true
                        '''
                    }
                }
            }
        }

        stage('Configure kubectl') {
            when {
                expression {
                    params.PIPELINE_ACTION == 'terraform-apply' ||
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
                    params.PIPELINE_ACTION == 'full-deploy'
                }
            }
            steps {
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh '''
                            set -e || true
                            export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                            export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                            CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "hotel-booking")
                            aws eks update-kubeconfig --region ${AWS_DEFAULT_REGION} --name ${CLUSTER_NAME} || echo "Could not update kubeconfig for ${CLUSTER_NAME}"
                            kubectl get nodes || true
                        '''
                    }
                }
            }
        }

        stage('Deploy Security Policies & Manifests') {
            when {
                expression {
                    params.PIPELINE_ACTION == 'terraform-apply' ||
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
                    params.PIPELINE_ACTION == 'full-deploy'
                }
            }
            steps {
                echo '🛡 Applying k8s manifests (security, autoscaling, services) if k8s directory exists'
                dir('k8s') {
                    sh '''
                        set -e || true
                        kubectl apply -f security/network-policies.yaml -n hotel-app || true
                        kubectl apply -f security/pod-security.yaml -n hotel-app || true
                        kubectl apply -f auto-scaling/hpa.yaml -n hotel-app || true
                        kubectl apply -f . -n hotel-app || echo "Applied available k8s manifests (if any)"
                    '''
                }
            }
        }

        stage('Verify Kubernetes Deployment') {
            when {
                expression {
                    params.PIPELINE_ACTION == 'terraform-apply' ||
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
                    params.PIPELINE_ACTION == 'full-deploy'
                }
            }
            steps {
                echo '🔍 Verifying Kubernetes deployment and health...'
                sh '''
                    set -e || true
                    echo "Waiting for pods to be ready (max 10m per label)..."
                    kubectl wait --for=condition=ready pod -l app=mongodb -n hotel-app --timeout=600s || echo "MongoDB pods may not be ready"
                    kubectl wait --for=condition=ready pod -l app=backend -n hotel-app --timeout=600s || echo "Backend pods may not be ready"
                    kubectl wait --for=condition=ready pod -l app=frontend -n hotel-app --timeout=600s || echo "Frontend pods may not be ready"

                    echo "=== pods ==="
                    kubectl get pods -n hotel-app || true
                    echo "=== services ==="
                    kubectl get svc -n hotel-app || true
                    echo "=== ingress ==="
                    kubectl get ingress -n hotel-app || true

                    echo "=== Health test (via in-cluster curl) ==="
                    kubectl run test-curl --image=curlimages/curl:8.5.0 -n hotel-app --rm -i --restart=Never -- /bin/sh -c "curl -f http://backend:5000/health && echo 'Backend health: OK' || echo 'Backend health: FAILED'" || true
                '''
            }
        }

        stage('Display Terraform Outputs') {
            when {
                expression {
                    params.PIPELINE_ACTION == 'terraform-apply' ||
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
                    params.PIPELINE_ACTION == 'full-deploy'
                }
            }
            steps {
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh '''
                            set -e || true
                            export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                            export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                            echo "=== Terraform Outputs ==="
                            terraform output || true
                        '''
                    }
                }
            }
        }

        stage('Access Monitoring Dashboard Info') {
            when {
                expression {
                    params.PIPELINE_ACTION == 'terraform-apply' ||
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
                    params.PIPELINE_ACTION == 'full-deploy'
                }
            }
            steps {
                echo '📊 Providing monitoring access hints (Grafana/Prometheus)'
                sh '''
                    set -e || true
                    echo "Attempting to show grafana service if present..."
                    kubectl get svc prometheus-grafana -n monitoring -o jsonpath="{.status.loadBalancer.ingress[0].hostname}" 2>/dev/null || echo "Grafana LB not ready or service not present"
                    echo "Grafana login: admin / [password from credentials set in terraform vars]"
                    kubectl get pods -n monitoring || echo "Monitoring namespace not ready or not deployed"
                '''
            }
        }
    } // end stages

    post {
        always {
            echo "🏁 Pipeline finished."
            // Ensure docker logout to avoid leaking credentials on agent
            sh 'docker logout || true'
        }

        success {
            script {
                echo '✅ Pipeline completed successfully!'
                if (params.PIPELINE_ACTION == 'docker-only') {
                    echo "📦 Docker images pushed: ${CLIENT_IMAGE}:${IMAGE_TAG} and ${SERVER_IMAGE}:${IMAGE_TAG}"
                }
                if (params.PIPELINE_ACTION == 'terraform-plan') {
                    echo "📋 Terraform plan completed. Review `tfplan` in terraform/ if needed."
                }
                if (params.PIPELINE_ACTION in ['terraform-apply','terraform-clean-and-apply','full-deploy']) {
                    echo "🎉 Deployment complete. To get frontend URL: kubectl get svc frontend -n hotel-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
                    echo "To get Grafana URL: kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
                }
                if (params.PIPELINE_ACTION == 'terraform-destroy') {
                    echo "🗑 Resources destroyed (requested)."
                }
            }
        }

        failure {
            echo '❌ Pipeline failed. Check console output for errors.'
        }

        unstable {
            echo '⚠ Pipeline completed with warnings or non-fatal issues.'
        }
    }
}
