pipeline {
    agent any

    parameters {
        choice(
            name: 'PIPELINE_ACTION',
            choices: ['docker-only', 'terraform-plan', 'terraform-apply', 'terraform-destroy', 'full-deploy', 'terraform-clean-and-apply'],
            description: 'Select action: docker-only (build & push images), terraform-plan/apply/destroy, full-deploy (both), or terraform-clean-and-apply (destroy and recreate)'
        )
    }

    environment {
        // Docker Hub credentials
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        DOCKERHUB_USERNAME = 'mennaomar12'
        CLIENT_IMAGE = "${DOCKERHUB_USERNAME}/hotel-client"
        SERVER_IMAGE = "${DOCKERHUB_USERNAME}/hotel-server"
        IMAGE_TAG = "${BUILD_NUMBER}"

        // Frontend environment variables
        VITE_BACKEND_URL = ''
        VITE_CURRENCY = '$'
        CLERK_KEY = credentials('clerk-publishable-key')
        STRIPE_KEY = credentials('stripe-publishable-key')

        // AWS Configuration
        AWS_DEFAULT_REGION = 'us-east-1'
    }

    stages {
        // ==================== CHECKOUT ====================
        stage('Checkout') {
            steps {
                echo '📥 Checking out code...'
                checkout scm
            }
        }

        // ==================== TERRAFORM CLEAN & DESTROY ====================
        stage('Terraform Destroy (Clean)') {
            when {
                expression {
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
                    params.PIPELINE_ACTION == 'terraform-destroy'
                }
            }
            steps {
                echo '🗑️ Destroying existing infrastructure...'
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                        string(credentialsId: 'mongodb-password', variable: 'MONGODB_PASSWORD'),
                        string(credentialsId: 'jwt-secret', variable: 'JWT_SECRET'),
                        string(credentialsId: 'grafana-admin-password', variable: 'GRAFANA_PASSWORD')
                    ]) {
                        sh '''
                            export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                            export TF_VAR_mongodb_root_password=$MONGODB_PASSWORD
                            export TF_VAR_jwt_secret=$JWT_SECRET
                            export TF_VAR_grafana_admin_password=$GRAFANA_PASSWORD
                            terraform destroy -auto-approve || echo "Destroy failed or nothing to destroy"
                        '''
                    }
                }
            }
        }

        stage('Clean Terraform State') {
            when {
                expression { params.PIPELINE_ACTION == 'terraform-clean-and-apply' }
            }
            steps {
                echo '🧹 Cleaning Terraform state...'
                dir('terraform') {
                    sh '''
                        rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl
                        echo "State cleaned"
                    '''
                }
            }
        }

        // ==================== DOCKER BUILD & PUSH ====================
        stage('Build Client Image') {
            when {
                expression {
                    params.PIPELINE_ACTION == 'docker-only' ||
                    params.PIPELINE_ACTION == 'full-deploy'
                }
            }
            steps {
                echo '🔨 Building Frontend Docker Image...'
                dir('client') {
                    sh """
                        docker build \
                        --build-arg VITE_BACKEND_URL=$VITE_BACKEND_URL \
                        --build-arg VITE_CURRENCY=$VITE_CURRENCY \
                        --build-arg VITE_CLERK_PUBLISHABLE_KEY=$CLERK_KEY \
                        --build-arg VITE_STRIPE_PUBLISHABLE_KEY=$STRIPE_KEY \
                        -t $CLIENT_IMAGE:$IMAGE_TAG \
                        -t $CLIENT_IMAGE:latest \
                        .
                    """
                }
            }
        }

        stage('Build Server Image') {
            when {
                expression {
                    params.PIPELINE_ACTION == 'docker-only' ||
                    params.PIPELINE_ACTION == 'full-deploy'
                }
            }
            steps {
                echo '🔨 Building Backend Docker Image...'
                dir('server') {
                    sh """
                        docker build \
                        -t $SERVER_IMAGE:$IMAGE_TAG \
                        -t $SERVER_IMAGE:latest \
                        .
                    """
                }
            }
        }

        stage('Login to Docker Hub') {
            when {
                expression {
                    params.PIPELINE_ACTION == 'docker-only' ||
                    params.PIPELINE_ACTION == 'full-deploy'
                }
            }
            steps {
                echo '🔐 Logging into Docker Hub...'
                sh "echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin"
            }
        }

        stage('Push Images to Docker Hub') {
            when {
                expression {
                    params.PIPELINE_ACTION == 'docker-only' ||
                    params.PIPELINE_ACTION == 'full-deploy'
                }
            }
            steps {
                echo '📤 Pushing images to Docker Hub...'
                sh """
                    docker push $CLIENT_IMAGE:$IMAGE_TAG
                    docker push $CLIENT_IMAGE:latest
                    docker push $SERVER_IMAGE:$IMAGE_TAG
                    docker push $SERVER_IMAGE:latest
                """
            }
        }

        stage('Docker Cleanup') {
            when {
                expression {
                    params.PIPELINE_ACTION == 'docker-only' ||
                    params.PIPELINE_ACTION == 'full-deploy'
                }
            }
            steps {
                echo '🧹 Cleaning up local Docker images...'
                sh """
                    docker rmi $CLIENT_IMAGE:$IMAGE_TAG || true
                    docker rmi $CLIENT_IMAGE:latest || true
                    docker rmi $SERVER_IMAGE:$IMAGE_TAG || true
                    docker rmi $SERVER_IMAGE:latest || true
                """
            }
        }

        // ==================== TERRAFORM DEPLOYMENT ====================
        stage('Terraform Init') {
            when {
                expression {
                    ['terraform-plan','terraform-apply','terraform-clean-and-apply','full-deploy'].contains(params.PIPELINE_ACTION)
                }
            }
            steps {
                echo '🔧 Initializing Terraform...'
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh '''
                            export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                            terraform init
                        '''
                    }
                }
            }
        }

        stage('Terraform Validate') {
            when {
                expression {
                    ['terraform-plan','terraform-apply','terraform-clean-and-apply','full-deploy'].contains(params.PIPELINE_ACTION)
                }
            }
            steps {
                echo '✔️ Validating Terraform configuration...'
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh '''
                            export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                            terraform validate
                        '''
                    }
                }
            }
        }

        stage('Terraform Plan') {
            when {
                expression {
                    ['terraform-plan','terraform-apply','terraform-clean-and-apply','full-deploy'].contains(params.PIPELINE_ACTION)
                }
            }
            steps {
                echo '📋 Running Terraform Plan...'
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                        string(credentialsId: 'mongodb-password', variable: 'MONGODB_PASSWORD'),
                        string(credentialsId: 'jwt-secret', variable: 'JWT_SECRET'),
                        string(credentialsId: 'grafana-admin-password', variable: 'GRAFANA_PASSWORD')
                    ]) {
                        sh '''
                            export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                            export TF_VAR_mongodb_root_password=$MONGODB_PASSWORD
                            export TF_VAR_jwt_secret=$JWT_SECRET
                            export TF_VAR_grafana_admin_password=$GRAFANA_PASSWORD
                            terraform plan -out=tfplan
                        '''
                    }
                }
            }
        }

        // ==================== CLEANUP EXISTING RESOURCES ====================
        stage('Cleanup Existing Resources') {
            when {
                expression {
                    ['terraform-apply','terraform-clean-and-apply','full-deploy'].contains(params.PIPELINE_ACTION)
                }
            }
            steps {
                echo '🧹 Cleaning up existing Kubernetes resources...'
                script {
                    try {
                        dir('terraform') {
                            withCredentials([
                                string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                                string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                            ]) {
                                sh '''
                                    export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                                    export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

                                    clusterName="hotel-booking"
                                    namespace="hotel-app"

                                    aws eks update-kubeconfig --region us-east-1 --name $clusterName
                                    kubectl delete deployment backend -n $namespace --ignore-not-found
                                    kubectl delete deployment frontend -n $namespace --ignore-not-found
                                    sleep 15
                                    kubectl get deployments -n $namespace
                                '''
                            }
                        }
                    } catch (Exception e) {
                        echo "⚠️ Warning: Cleanup encountered an error: ${e.message}"
                        echo "Continuing with deployment..."
                    }
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression {
                    ['terraform-apply','terraform-clean-and-apply','full-deploy'].contains(params.PIPELINE_ACTION)
                }
            }
            steps {
                echo '🚀 Applying Terraform changes automatically...'
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                        string(credentialsId: 'mongodb-password', variable: 'MONGODB_PASSWORD'),
                        string(credentialsId: 'jwt-secret', variable: 'JWT_SECRET'),
                        string(credentialsId: 'grafana-admin-password', variable: 'GRAFANA_PASSWORD')
                    ]) {
                        sh '''
                            export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                            export TF_VAR_mongodb_root_password=$MONGODB_PASSWORD
                            export TF_VAR_jwt_secret=$JWT_SECRET
                            export TF_VAR_grafana_admin_password=$GRAFANA_PASSWORD
                            terraform apply -auto-approve tfplan
                        '''
                    }
                }
            }
        }

        stage('Configure kubectl') {
            when {
                expression {
                    ['terraform-apply','terraform-clean-and-apply','full-deploy'].contains(params.PIPELINE_ACTION)
                }
            }
            steps {
                echo '⚙️ Configuring kubectl...'
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh '''
                            export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                            CLUSTER_NAME=$(terraform output -raw cluster_name)
                            aws eks update-kubeconfig --region us-east-1 --name $CLUSTER_NAME
                            echo "✅ kubectl configured successfully"
                        '''
                    }
                }
            }
        }

        // ==================== MONITORING ====================
        stage('Verify Monitoring') {
            when {
                expression { params.PIPELINE_ACTION == 'full-deploy' }
            }
            steps {
                echo '🔍 Verifying monitoring stack...'
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh '''
                            export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

                            echo "Checking Prometheus..."
                            kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus || echo "Prometheus not deployed"

                            echo "Checking Grafana..."
                            kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana || echo "Grafana not deployed"

                            echo "Checking AlertManager..."
                            kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager || echo "AlertManager not deployed"

                            echo "Checking ServiceMonitors..."
                            kubectl get servicemonitor -n hotel-app || echo "ServiceMonitors not deployed"
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                if (['docker-only','full-deploy'].contains(params.PIPELINE_ACTION)) {
                    sh 'docker logout || echo Already logged out'
                }
            }
        }

        success {
            script {
                echo '✅✅✅ Pipeline completed successfully! ✅✅✅'
                echo "================================================"
            }
        }
    }
}
