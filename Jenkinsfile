pipeline {
    environment {
        APP_DIR         = 'cartforge'
        AWS_REGION      = 'us-east-1'
        AWS_ACCOUNT_ID  = '256097482448'
        ECR_REPO        = 'cartforge'
        IMAGE_TAG       = "${env.BUILD_NUMBER}"
        ECR_URI         = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
        ECS_CLUSTER     = 'cartforge-cluster'
        ECS_SERVICE     = 'cartforge-service'
        TASK_DEF_FAMILY = 'cartforge-task'
    }
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    stages {

        stage('Checkout') {
            steps {
                 git branch: 'main', url: 'https://github.com/mantu0tech/cartforge.git'
            }
        }

        // Secret scanning covers the WHOLE repo (aws/, scripts/, security/,
        // cartforge/ - everything) since a leaked key could land in any
        // folder, not just the app code. Runs before anything is built or
        // pushed anywhere.
        stage('Gitleaks - secret scan') {
            steps {
                sh '''
                    docker run --rm -v "$PWD:/repo" zricethezav/gitleaks:latest \
                        detect --source /repo --report-format json \
                        --report-path /repo/gitleaks-report.json --exit-code 1
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'gitleaks-report.json', allowEmptyArchive: true
                }
            }
        }

        // Everything below this point that touches the app runs inside
        // dir("${APP_DIR}") - so `npm ci` reads cartforge/package.json,
        // not a (nonexistent) one at the repo root.
        stage('Install & Build (npm)') {
            steps {
                dir("${APP_DIR}") {
                    sh '''
                        npm ci
                        npm run build
                    '''
                }
            }
        }

        stage('Docker Build') {
            steps {
                dir("${APP_DIR}") {
                    sh "docker build -t ${ECR_REPO}:${IMAGE_TAG} ."
                }
            }
        }

        stage('Trivy - image scan') {
            steps {
                sh '''
                    docker run --rm \
                        -v /var/run/docker.sock:/var/run/docker.sock \
                        aquasec/trivy:latest image \
                        --severity HIGH,CRITICAL --exit-code 1 --no-progress \
                        ${ECR_REPO}:${IMAGE_TAG}
                '''
            }
        }

        stage('Push to ECR') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins-creds']]) {
                    sh '''
                        aws ecr get-login-password --region ${AWS_REGION} | \
                            docker login --username AWS --password-stdin ${ECR_URI}

                        docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_URI}:${IMAGE_TAG}
                        docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_URI}:latest

                        docker push ${ECR_URI}:${IMAGE_TAG}
                        docker push ${ECR_URI}:latest
                    '''
                }
            }
        }

        stage('Record current task definition (rollback target)') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins-creds']]) {
                    sh '''
                        CURRENT_ARN=$(aws ecs describe-services \
                            --cluster ${ECS_CLUSTER} --services ${ECS_SERVICE} \
                            --region ${AWS_REGION} \
                            --query 'services[0].taskDefinition' --output text 2>/dev/null || echo "NONE")

                        echo "$CURRENT_ARN" > previous-task-def-arn.txt
                        echo "Current (previous) task definition: $CURRENT_ARN"
                    '''
                }
                archiveArtifacts artifacts: 'previous-task-def-arn.txt'
            }
        }

        stage('Register new ECS task definition') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins-creds']]) {
                    sh '''
                        NEW_IMAGE="${ECR_URI}:${IMAGE_TAG}"

                        aws ecs describe-task-definition \
                            --task-definition ${TASK_DEF_FAMILY} \
                            --region ${AWS_REGION} \
                            --query 'taskDefinition' > current-task-def.json

                        jq --arg IMAGE "$NEW_IMAGE" \
                           '.containerDefinitions[0].image = $IMAGE |
                            del(.taskDefinitionArn, .revision, .status,
                                .requiresAttributes, .compatibilities,
                                .registeredAt, .registeredBy)' \
                           current-task-def.json > new-task-def.json

                        aws ecs register-task-definition \
                            --cli-input-json file://new-task-def.json \
                            --region ${AWS_REGION} > registered-task-def.json

                        NEW_ARN=$(jq -r '.taskDefinition.taskDefinitionArn' registered-task-def.json)
                        echo "$NEW_ARN" > new-task-def-arn.txt
                        echo "Registered: $NEW_ARN"
                    '''
                }
            }
        }

        stage('Deploy to ECS (rolling + circuit breaker)') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins-creds']]) {
                    sh '''
                        NEW_ARN=$(cat new-task-def-arn.txt)

                        aws ecs update-service \
                            --cluster ${ECS_CLUSTER} \
                            --service ${ECS_SERVICE} \
                            --task-definition "$NEW_ARN" \
                            --deployment-configuration "deploymentCircuitBreaker={enable=true,rollback=true},maximumPercent=200,minimumHealthyPercent=100" \
                            --region ${AWS_REGION} > /dev/null

                        echo "Deployment started with task definition: $NEW_ARN"
                    '''
                }
            }
        }

        stage('Wait for service to stabilize') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins-creds']]) {
                    sh '''
                        aws ecs wait services-stable \
                            --cluster ${ECS_CLUSTER} \
                            --services ${ECS_SERVICE} \
                            --region ${AWS_REGION}
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Build #${env.BUILD_NUMBER} deployed successfully to ECS."
        }
        failure {
            script {
                if (fileExists('previous-task-def-arn.txt')) {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins-creds']]) {
                        sh '''
                            PREVIOUS_ARN=$(cat previous-task-def-arn.txt)
                            if [ "$PREVIOUS_ARN" != "NONE" ] && [ -n "$PREVIOUS_ARN" ]; then
                                echo "Rolling back ${ECS_SERVICE} to $PREVIOUS_ARN"
                                aws ecs update-service \
                                    --cluster ${ECS_CLUSTER} \
                                    --service ${ECS_SERVICE} \
                                    --task-definition "$PREVIOUS_ARN" \
                                    --region ${AWS_REGION} > /dev/null

                                aws ecs wait services-stable \
                                    --cluster ${ECS_CLUSTER} \
                                    --services ${ECS_SERVICE} \
                                    --region ${AWS_REGION} || true
                            else
                                echo "No previous task definition recorded - nothing to roll back to (likely the first-ever deployment)."
                            fi
                        '''
                    }
                }
            }
            echo "Pipeline failed - rolled back ${ECS_SERVICE} to the previous task definition."
        }
    }
}


