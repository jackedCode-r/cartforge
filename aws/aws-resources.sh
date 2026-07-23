#!/usr/bin/env bash
# Reference commands only - run these one at a time from the Jenkins EC2 (or
# your laptop) after `aws configure`. Replace the placeholder values first.
# This is NOT meant to be run top-to-bottom blindly.
set -euo pipefail

AWS_REGION="us-east-1"
VPC_ID="vpc-06df35f7d668b64a1"
SUBNET_IDS="subnet-0b4b36ab3e084c5f2,subnet-0b5fed250cf90265a,subnet-03842953cc80edc98"
SG_ID="sg-0a53e7118605951de"
CLUSTER_NAME="cartforge-cluster"
SERVICE_NAME="cartforge-service"
ALB_NAME="cartforge-alb"

# 1. ECR repository ---------------------------------------------------------
aws ecr create-repository --repository-name cartforge --region "$AWS_REGION"

# 2. ECS cluster (Fargate) ----------------------------------------------------
aws ecs create-cluster --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION"

# 3. Application Load Balancer + two target groups (blue/green) -------------
aws elbv2 create-load-balancer \
  --name "$ALB_NAME" --subnets $(echo $SUBNET_IDS | tr ',' ' ') \
  --security-groups "$SG_ID" --region "$AWS_REGION"

aws elbv2 create-target-group \
  --name cartforge-tg-blue --protocol HTTP --port 80 \
  --vpc-id "$VPC_ID" --target-type ip --region "$AWS_REGION"

aws elbv2 create-target-group \
  --name cartforge-tg-green --protocol HTTP --port 80 \
  --vpc-id "$VPC_ID" --target-type ip --region "$AWS_REGION"

# Create a listener on the ALB pointing at the "blue" target group by default,
# then note the listener ARN and both target group ARNs - CodeDeploy needs them.

# 4. Register the initial task definition ------------------------------------
aws ecs register-task-definition --cli-input-json file://ecs/taskdef.json --region "$AWS_REGION"

# 5. ECS service with CODE_DEPLOY as the deployment controller --------------
# (deploymentController type CODE_DEPLOY hands blue/green traffic shifting
# over to CodeDeploy instead of ECS's own rolling update)
aws ecs create-service \
  --cluster "$CLUSTER_NAME" \
  --service-name "$SERVICE_NAME" \
  --task-definition cartforge-task \
  --desired-count 2 \
  --launch-type FARGATE \
  --deployment-controller type=CODE_DEPLOY \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
  --load-balancers "targetGroupArn=<BLUE_TG_ARN>,containerName=cartforge,containerPort=80" \
  --region "$AWS_REGION"

# 6. CodeDeploy application + deployment group (the canary config is what
#    gives you the 10%-then-rest traffic shift, and it's what makes
#    automatic rollback possible) --------------------------------------------
aws deploy create-application \
  --application-name cartforge-app \
  --compute-platform ECS \
  --region "$AWS_REGION"

aws deploy create-deployment-group \
  --application-name cartforge-app \
  --deployment-group-name cartforge-deployment-group \
  --deployment-config-name CodeDeployDefault.ECSCanary10Percent5Minutes \
  --service-role-arn arn:aws:iam::123456789012:role/CodeDeployECSRole \
  --ecs-services clusterName="$CLUSTER_NAME",serviceName="$SERVICE_NAME" \
  --auto-rollback-configuration enabled=true,events=DEPLOYMENT_FAILURE,DEPLOYMENT_STOP_ON_ALARM \
  --alarm-configuration enabled=true,alarms=[name=cartforge-5xx-alarm] \
  --load-balancer-info "targetGroupPairInfoList=[{targetGroups=[{name=cartforge-tg-blue},{name=cartforge-tg-green}],prodTrafficRoute={listenerArns=[<LISTENER_ARN>]}}]" \
  --region "$AWS_REGION"

# 7. CloudWatch alarm that CodeDeploy watches to trigger an automatic
#    rollback mid-deployment (this is the "if anything fails, roll back"
#    piece, on top of CodeDeploy's own failure/timeout rollback) ------------
aws cloudwatch put-metric-alarm \
  --alarm-name cartforge-5xx-alarm \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --dimensions Name=LoadBalancer,Value=<ALB_ARN_SUFFIX> \
  --statistic Sum \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --region "$AWS_REGION"
