#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="us-east-1"

CLUSTER_NAME="cartforge-cluster"
SERVICE_NAME="cartforge-service"
ALB_NAME="cartforge-alb"
TG_BLUE_NAME="cartforge-tg-blue"
TG_GREEN_NAME="cartforge-tg-green"
ECR_REPO_NAME="cartforge"
TASK_FAMILY="cartforge-task"
CODEDEPLOY_APP="cartforge-app"
CODEDEPLOY_GROUP="cartforge-deployment-group"
ALARM_NAME="cartforge-5xx-alarm"
EXEC_ROLE_NAME="ecsTaskExecutionRole"
DEPLOY_ROLE_NAME="CodeDeployECSRole"

echo "===== Cleaning AWS Resources ====="

###########################################
# CodeDeploy Deployment Group
###########################################

echo "Deleting CodeDeploy Deployment Group..."

aws deploy delete-deployment-group \
    --application-name "$CODEDEPLOY_APP" \
    --deployment-group-name "$CODEDEPLOY_GROUP" \
    --region "$AWS_REGION" >/dev/null 2>&1 || true

###########################################
# CodeDeploy Application
###########################################

echo "Deleting CodeDeploy Application..."

aws deploy delete-application \
    --application-name "$CODEDEPLOY_APP" \
    --region "$AWS_REGION" >/dev/null 2>&1 || true

###########################################
# ECS Service
###########################################

echo "Deleting ECS Service..."

aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service "$SERVICE_NAME" \
    --desired-count 0 \
    --region "$AWS_REGION" >/dev/null 2>&1 || true

aws ecs delete-service \
    --cluster "$CLUSTER_NAME" \
    --service "$SERVICE_NAME" \
    --force \
    --region "$AWS_REGION" >/dev/null 2>&1 || true

echo "Waiting for ECS service deletion..."

while aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$AWS_REGION" \
    --query "services[0].status" \
    --output text 2>/dev/null | grep -q ACTIVE; do
    sleep 5
done

###########################################
# ECS Cluster
###########################################

echo "Deleting ECS Cluster..."

aws ecs delete-cluster \
    --cluster "$CLUSTER_NAME" \
    --region "$AWS_REGION" >/dev/null 2>&1 || true

###########################################
# Task Definitions
###########################################

echo "Deregistering Task Definitions..."

TASKS=$(aws ecs list-task-definitions \
    --family-prefix "$TASK_FAMILY" \
    --region "$AWS_REGION" \
    --query "taskDefinitionArns[]" \
    --output text 2>/dev/null || true)

for td in $TASKS
do
    aws ecs deregister-task-definition \
        --task-definition "$td" \
        --region "$AWS_REGION" >/dev/null 2>&1 || true
done

###########################################
# ALB
###########################################

echo "Deleting Load Balancer..."

ALB_ARN=$(aws elbv2 describe-load-balancers \
    --names "$ALB_NAME" \
    --region "$AWS_REGION" \
    --query "LoadBalancers[0].LoadBalancerArn" \
    --output text 2>/dev/null || true)

if [[ "$ALB_ARN" != "None" && -n "$ALB_ARN" ]]; then

    LISTENERS=$(aws elbv2 describe-listeners \
        --load-balancer-arn "$ALB_ARN" \
        --region "$AWS_REGION" \
        --query "Listeners[].ListenerArn" \
        --output text)

    for L in $LISTENERS
    do
        aws elbv2 delete-listener \
            --listener-arn "$L" \
            --region "$AWS_REGION" >/dev/null 2>&1 || true
    done

    aws elbv2 delete-load-balancer \
        --load-balancer-arn "$ALB_ARN" \
        --region "$AWS_REGION" >/dev/null 2>&1 || true

    echo "Waiting for ALB deletion..."

    sleep 30
fi

###########################################
# Target Groups
###########################################

echo "Deleting Target Groups..."

for TG in "$TG_BLUE_NAME" "$TG_GREEN_NAME"
do

TG_ARN=$(aws elbv2 describe-target-groups \
    --names "$TG" \
    --region "$AWS_REGION" \
    --query "TargetGroups[0].TargetGroupArn" \
    --output text 2>/dev/null || true)

if [[ "$TG_ARN" != "None" && -n "$TG_ARN" ]]; then

aws elbv2 delete-target-group \
    --target-group-arn "$TG_ARN" \
    --region "$AWS_REGION" >/dev/null 2>&1 || true

fi

done

###########################################
# CloudWatch Alarm
###########################################

echo "Deleting CloudWatch Alarm..."

aws cloudwatch delete-alarms \
    --alarm-names "$ALARM_NAME" \
    --region "$AWS_REGION" >/dev/null 2>&1 || true

###########################################
# ECR Repository
###########################################

echo "Deleting ECR Repository..."

aws ecr delete-repository \
    --repository-name "$ECR_REPO_NAME" \
    --force \
    --region "$AWS_REGION" >/dev/null 2>&1 || true

###########################################
# IAM Roles
###########################################

echo "Deleting IAM Roles..."

aws iam detach-role-policy \
    --role-name "$EXEC_ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy >/dev/null 2>&1 || true

aws iam delete-role \
    --role-name "$EXEC_ROLE_NAME" >/dev/null 2>&1 || true

aws iam detach-role-policy \
    --role-name "$DEPLOY_ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS >/dev/null 2>&1 || true

aws iam delete-role \
    --role-name "$DEPLOY_ROLE_NAME" >/dev/null 2>&1 || true

echo
echo "======================================="
echo "All CartForge AWS resources deleted."
echo "======================================="