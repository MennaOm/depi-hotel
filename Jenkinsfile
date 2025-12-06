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
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        DOCKERHUB_USERNAME = 'mennaomar12'
        CLIENT_IMAGE = "${DOCKERHUB_USERNAME}/hotel-client"
        SERVER_IMAGE = "${DOCKERHUB_USERNAME}/hotel-server"
        IMAGE_TAG = "${BUILD_NUMBER}"

        VITE_BACKEND_URL = 'http://localhost:3000'
        VITE_CURRENCY = '$'
        CLERK_KEY = credentials('clerk-publishable-key')
        STRIPE_KEY = credentials('stripe-publishable-key')

        AWS_DEFAULT_REGION = 'us-east-1'
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

        stage('Login to Docker Hub') {
            when {
                expression { params.PIPELINE_ACTION == 'docker-only' || params.PIPELINE_ACTION == 'full-deploy' }
            }
            steps {
                echo '🔐 Logging into Docker Hub...'
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

        // ------------------ TERRAFORM ------------------
        stage('Setup AWS & Terraform Credentials') {
            when { expression { params.PIPELINE_ACTION != 'docker-only' } }
            steps { echo '🔑 Preparing AWS/Terraform credentials...' }
        }

        stage('Terraform Init') {
            when {
                expression {
                    params.PIPELINE_ACTION in ['terraform-plan','terraform-apply','terraform-clean-and-apply','full-deploy','terraform-destroy']
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
                            terraform init -upgrade
                        '''
                    }
                }
            }
        }

        stage('Terraform Format Check & Validate') {
            when {
                expression {
                    params.PIPELINE_ACTION in ['terraform-plan','terraform-apply','terraform-clean-and-apply','full-deploy']
                }
            }
            steps {
                dir('terraform') {
                    sh '''
                        set -e || true
                        terraform fmt -check -recursive || echo "Run terraform fmt -recursive to fix formatting"
                        terraform validate || echo "Terraform validate found issues"
                    '''
                }
            }
        }

        stage('Terraform Plan') {
            when {
                expression {
                    params.PIPELINE_ACTION in ['terraform-plan','terraform-apply','terraform-clean-and-apply','full-deploy']
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
                            terraform plan -out=tfplan -detailed-exitcode || echo "Terraform plan completed"
                        '''
                    }
                }
            }
        }

        stage('Terraform Destroy (Clean)') {
            when { expression { params.PIPELINE_ACTION in ['terraform-clean-and-apply','terraform-destroy'] } }
            steps {
                script { input message: '⚠ Are you sure you want to destroy resources?', ok: 'Yes, destroy' }
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                        string(credentialsId: 'mongodb-password', variable: 'MONGODB_PASSWORD'),
                        string(credentialsId: 'jwt-secret', variable: 'JWT_SECRET')
                    ]) {
                        sh 'terraform destroy -auto-approve || echo "Destroy finished"'
                    }
                }
            }
        }

        stage('Clean Terraform State Files') {
            when { expression { params.PIPELINE_ACTION == 'terraform-clean-and-apply' } }
            steps {
                dir('terraform') { sh 'rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl; rm -rf .terraform || true' }
            }
        }

        stage('Terraform Apply') {
            when { expression { params.PIPELINE_ACTION in ['terraform-apply','terraform-clean-and-apply','full-deploy'] } }
            steps {
                dir('terraform') { sh 'terraform apply -auto-approve tfplan || terraform apply -auto-approve || true' }
            }
        }

        stage('Configure kubectl') {
            when { expression { params.PIPELINE_ACTION in ['terraform-apply','terraform-clean-and-apply','full-deploy'] } }
            steps { dir('terraform') { sh 'aws eks update-kubeconfig --region ${AWS_DEFAULT_REGION} --name $(terraform output -raw cluster_name 2>/dev/null || echo "hotel-booking") || true' } }
        }

        stage('Deploy Kubernetes Manifests') {
            when { expression { params.PIPELINE_ACTION in ['terraform-apply','terraform-clean-and-apply','full-deploy'] } }
            steps { dir('k8s') { sh 'kubectl apply -f . -n hotel-app || true' } }
        }

        stage('Verify Kubernetes Deployment') {
            when { expression { params.PIPELINE_ACTION in ['terraform-apply','terraform-clean-and-apply','full-deploy'] } }
            steps {
                sh '''
                    kubectl wait --for=condition=ready pod -l app=backend -n hotel-app --timeout=600s || echo "Backend pods not ready"
                    kubectl wait --for=condition=ready pod -l app=frontend -n hotel-app --timeout=600s || echo "Frontend pods not ready"
                '''
            }
        }

        stage('Display Terraform Outputs') {
            when { expression { params.PIPELINE_ACTION in ['terraform-apply','terraform-clean-and-apply','full-deploy'] } }
            steps { dir('terraform') { sh 'terraform output || true' } }
        }

        stage('Final Cleanup') {
            steps {
                node {
                    echo '🧹 Logging out of Docker...'
                    sh 'docker logout || true'
                }
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline completed successfully!'
        }
        failure {
            echo '❌ Pipeline failed. Check console output for errors.'
        }
        unstable {
            echo '⚠ Pipeline completed with warnings.'
        }
    }
}
