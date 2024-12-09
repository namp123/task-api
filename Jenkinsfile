pipeline {
    agent any

    //define env variables
    environment {
        GOOGLE_CREDENTIALS = credentials('gcp-service-account')  
        DOCKER_REGISTRY = 'gcr.io/task'                
        IMAGE_NAME = 'task-api-app'                          
        TF_VARS_PATH = 'terraform.tfvars'
        DOCKERFILE = 'Dockerfile'                        
        NODE_ENV = 'production'                                    
    }

    stages {
        //stage 1 -> Clone the repository onto the jenkins server
        stage('Clone Repository') {
            steps {
                git 'https://github.com/your-repo/your-nodejs-app.git'
            }
        }

        //stage 2 -> Install npm dependency on this jenkins server/agent
        stage('Install Dependencies') {
            steps {
                script {
                    sh 'npm install'
                }
            }
        }

        //stage 3 -> Run the predefined mocha unit test on the jenkins server/agent
        stage('Run Unit Tests') {
            steps {
                script {
                    // Run Mocha tests
                    sh 'npm test'
                }
            }
        }

        //stage 4 -> by accessing Dockerfile from the cloned repo we then build it to create the docker image on the jenkins server which tags it with a unique build id ($BUILD_ID is an inbuilt jenkins variable)
        stage('Build Docker Image') {
            steps {
                script {
                    sh "docker build -f $DOCKERFILE -t $DOCKER_REGISTRY/$IMAGE_NAME:$BUILD_ID ."
                }
            }
        }

        //stage 5 - > Push the created Docker image from the jenkins server/agent to Google cloud container registry
        stage('Push Docker Image to Container Registry') {
            steps {
                script {
                    sh "docker login -u _json_key --password-stdin https://gcr.io <<< $GOOGLE_CREDENTIALS" // First Log in to Google Cloud
                    sh 'docker push $DOCKER_REGISTRY/$IMAGE_NAME:$BUILD_ID' //push it onto the registry
                }
            }
        }

        //stage 6 -> Automatically deploy resources using the terraform script
        stage('Deploy Infrastructure with Terraform') {
            steps {
                script {
                    sh 'cd terraform'
                    sh 'terraform init' // Initialize Terraform
                    sh 'terraform apply -var-file=$TF_VARS_PATH -auto-approve' // Apply Terraform configuration to deploy the infrastructure, using terraform.tfvars
                }
            }
        }

        //stage 7 -> newly deployed vms on gcp should pull the docker images from gcr
        stage('Deploy Docker Container to Cloud') {
            steps {
                script {
                    //for eg: using GKE we create a deployment from this image
                    sh 'kubectl set image deployment/your-deployment-name your-container-name=$DOCKER_REGISTRY/$IMAGE_NAME:$BUILD_ID'
                }
            }
        }

        //stage 8 -> clean up the docker images from the jenkins server/agent to free up space, these are no longer required as they are now in gcr
        stage('Clean Up') {
            steps {
                script {
                    sh 'docker system prune -f'
                }
            }
        }
    }

//post script (to print after all stages have been parsed through)
    post {
        success {
            echo "Deployment completed successfully!"
        }
        failure {
            echo "Deployment failed!"
        }
    }
}

