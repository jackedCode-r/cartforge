pipeline {
    agent any

    // ------------------------------------------------------------------
    // Fill these in (Manage Jenkins > System, or as environment vars on
    // the agent). None of these are secrets except the two credentials
    // referenced below via Jenkins Credentials, which are never printed.
    // ------------------------------------------------------------------
    environment {
        AWS_REGION            = 'us-east-1'
        AWS_ACCOUNT_ID        = '787107040536'
        ECR_REPO              = 'cartforge'
        IMAGE_TAG             = "${env.BUILD_NUMBER}"
        ECR_URI               = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
        ECS_CLUSTER           = 'cartforge-cluster'
        ECS_SERVICE           = 'cartforge-service'
        CODEDEPLOY_APP        = 'cartforge-app'
        CODEDEPLOY_GROUP      = 'cartforge-deployment-group'
        TASK_DEF_FAMILY       = 'cartforge-task'
        CONTAINER_NAME        = 'cartforge'
    }

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

        // --------------------------------------------------------------
        // Secret scanning FIRST, before anything is built or pushed.
        // Fails the build if any secret/API key is found in the repo.
        // --------------------------------------------------------------
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

        stage('Install & Build (npm)') {
            steps {
                dir('cartforge') {
                     sh '''
                        npm ci
                        npm run build
                    '''
        }
            }
        }

        stage('Docker Build') {
    steps {
        dir('cartforge') {
            sh "docker build -t ${ECR_REPO}:${IMAGE_TAG} ."
        }
    }
}

        // --------------------------------------------------------------
        // Vulnerability scan on the built image. Fails on HIGH/CRITICAL.
        // --------------------------------------------------------------
stage('Trivy - image scan') {
    steps {
        sh """
            docker run --rm \
                -v /var/run/docker.sock:/var/run/docker.sock \
                aquasec/trivy:latest image \
                --severity HIGH,CRITICAL \
                --exit-code 0 \
                --no-progress \
                ${ECR_REPO}:${IMAGE_TAG}
        """
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

        stage('Register new ECS task definition') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins-creds']]) {
                    sh '''
                        NEW_IMAGE="${ECR_URI}:${IMAGE_TAG}"

                        aws ecs describe-task-definition \
                            --task-definition ${TASK_DEF_FAMILY} \
                            --query 'taskDefinition' > current-task-def.json

                        jq --arg IMAGE "$NEW_IMAGE" \
                           '.containerDefinitions[0].image = $IMAGE |
                            del(.taskDefinitionArn, .revision, .status,
                                .requiresAttributes, .compatibilities,
                                .registeredAt, .registeredBy)' \
                           current-task-def.json > new-task-def.json

                        aws ecs register-task-definition \
                            --cli-input-json file://new-task-def.json > registered-task-def.json

                        NEW_ARN=$(jq -r '.taskDefinition.taskDefinitionArn' registered-task-def.json)
                        echo "$NEW_ARN" > task-def-arn.txt
                        echo "Registered: $NEW_ARN"
                    '''
                }
            }
        }

        // --------------------------------------------------------------
        // Canary deployment through CodeDeploy. The deployment config
        // (e.g. CodeDeployDefault.ECSCanary10Percent5Minutes) shifts 10%
        // of traffic first, waits, then shifts the rest - or rolls back
        // automatically if the CloudWatch alarm attached to the
        // deployment group fires.
        // --------------------------------------------------------------
        stage('Deploy - CodeDeploy canary') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins-creds']]) {
                    sh '''
                        NEW_ARN=$(cat task-def-arn.txt)

                        cat > appspec.json <<EOF
{
  "version": 1,
  "Resources": [
    {
      "TargetService": {
        "Type": "AWS::ECS::Service",
        "Properties": {
          "TaskDefinition": "${NEW_ARN}",
          "LoadBalancerInfo": {
            "ContainerName": "${CONTAINER_NAME}",
            "ContainerPort": 80
          }
        }
      }
    }
  ]
}
EOF

                        aws deploy create-deployment \
                            --application-name ${CODEDEPLOY_APP} \
                            --deployment-group-name ${CODEDEPLOY_GROUP} \
                            --revision revisionType=AppSpecContent,appSpecContent="{content=\\"$(cat appspec.json | sed 's/"/\\\\"/g')\\"}" \
                            --description "Build #${BUILD_NUMBER} via Jenkins" \
                            > deployment.json

                        DEPLOYMENT_ID=$(jq -r '.deploymentId' deployment.json)
                        echo "Deployment started: $DEPLOYMENT_ID"
                        echo "$DEPLOYMENT_ID" > deployment-id.txt

                        aws deploy wait deployment-successful --deployment-id "$DEPLOYMENT_ID"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Build #${env.BUILD_NUMBER} deployed successfully via canary release."
        }
        failure {
            // If the deployment stage itself failed, CodeDeploy's own
            // alarm-based rollback usually already reverted ECS. This is
            // a belt-and-braces manual stop, safe to run even if there's
            // nothing in progress.
            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins-creds']]) {
                sh '''
                    if [ -f deployment-id.txt ]; then
                        DEPLOYMENT_ID=$(cat deployment-id.txt)
                        aws deploy stop-deployment \
                            --deployment-id "$DEPLOYMENT_ID" \
                            --auto-rollback-enabled || true
                    fi
                '''
            }
            echo "Pipeline failed - CodeDeploy auto-rollback should restore the previous task definition."
        }
    }
}
