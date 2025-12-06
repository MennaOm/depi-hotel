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
        DOCKERHUB_USERNAME = 'marvelhelmy'
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
        stage('Checkout') {
            steps {
                echo '📥 Checking out code...'
                checkout scm
            }
        }

        // ==================== TERRAFORM CLEAN / DESTROY ====================
        stage('Terraform Clean & Destroy') {
            when {
                expression { params.PIPELINE_ACTION in ['terraform-clean-and-apply', 'terraform-destroy'] }
            }
            steps {
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

                    // Clean state if needed
                    when { expression { params.PIPELINE_ACTION == 'terraform-clean-and-apply' } }
                    sh '''
                        rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl
                        echo "Terraform state cleaned"
                    '''
                }
            }
        }

        // ==================== DOCKER BUILD & PUSH (PARALLEL) ====================
        stage('Docker Build & Push') {
            when {
                expression { params.PIPELINE_ACTION in ['docker-only', 'full-deploy'] }
            }
            parallel {
                stage('Build & Push Client') {
                    steps {
                        dir('client') {
                            sh """
                                docker build \\
                                    --build-arg VITE_BACKEND_URL=$VITE_BACKEND_URL \\
                                    --build-arg VITE_CURRENCY=$VITE_CURRENCY \\
                                    --build-arg VITE_CLERK_PUBLISHABLE_KEY=$CLERK_KEY \\
                                    --build-arg VITE_STRIPE_PUBLISHABLE_KEY=$STRIPE_KEY \\
                                    -t $CLIENT_IMAGE:$IMAGE_TAG \\
                                    -t $CLIENT_IMAGE:latest .
                            """
                        }
                        sh "echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin"
                        sh """
                            docker push $CLIENT_IMAGE:$IMAGE_TAG
                            docker push $CLIENT_IMAGE:latest
                            docker rmi $CLIENT_IMAGE:$IMAGE_TAG $CLIENT_IMAGE:latest || true
                        """
                    }
                }

                stage('Build & Push Server') {
                    steps {
                        dir('server') {
                            sh """
                                docker build -t $SERVER_IMAGE:$IMAGE_TAG -t $SERVER_IMAGE:latest .
                            """
                        }
                        sh "echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin"
                        sh """
                            docker push $SERVER_IMAGE:$IMAGE_TAG
                            docker push $SERVER_IMAGE:latest
                            docker rmi $SERVER_IMAGE:$IMAGE_TAG $SERVER_IMAGE:latest || true
                        """
                    }
                }
            }
        }

        // ==================== TERRAFORM DEPLOYMENT ====================
        stage('Terraform Deployment') {
            when {
                expression { params.PIPELINE_ACTION in ['terraform-plan', 'terraform-apply', 'terraform-clean-and-apply', 'full-deploy'] }
            }
            steps {
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
                            terraform init
                            terraform validate
                            terraform plan -out=tfplan
                        '''
                        script {
                            if (params.PIPELINE_ACTION in ['terraform-apply', 'terraform-clean-and-apply', 'full-deploy']) {
                                sh 'terraform apply -auto-approve tfplan'
                            }
                        }
                    }
                }
            }
        }

        // ==================== KUBERNETES DEPLOYMENT ====================
        stage('Kubernetes Deploy & Verify') {
            when {
                expression { params.PIPELINE_ACTION in ['terraform-apply', 'terraform-clean-and-apply', 'full-deploy'] }
            }
            steps {
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

                            kubectl delete deployment backend frontend -n hotel-app --ignore-not-found=true

                            echo "=== Cluster Nodes ==="
                            kubectl get nodes
                            echo "=== Pods in hotel-app ==="
                            kubectl get pods -n hotel-app
                            echo "=== Deployments ==="
                            kubectl get deployments -n hotel-app
                            echo "=== Services ==="
                            kubectl get svc -n hotel-app
                        '''
                    }
                }
            }
        }

        // ==================== MONITORING ====================
        stage('Monitoring Stack') {
            when {
                expression { params.PIPELINE_ACTION == 'full-deploy' }
            }
            steps {
                sh '''
                    echo "Checking monitoring stack..."
                    kubectl get pods -n monitoring
                    kubectl get svc -n monitoring
                '''
            }
        }
    }

    post {
        always {
            sh 'docker logout || true'
        }
        success {
            echo '✅ Pipeline completed successfully!'
        }
        failure {
            echo '❌ Pipeline failed!'
        }
    }
}
