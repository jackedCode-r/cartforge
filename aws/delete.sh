#!/usr/bin/env bash

set -euo pipefail

AWS_REGION="us-east-1"

CLUSTER_NAME="cartforge-cluster"
SERVICE_NAME="cartforge-service"
TASK_FAMILY="cartforge-task"

ALB_NAME="cartforge-alb"
TG_NAME="cartforge-tg"

ECR_REPO_NAME="cartforge"

ALARM_NAME="cartforge-5xx-alarm"

EXEC_ROLE_NAME="ecsTaskExecutionRole"

echo "======================================="
echo "Deleting CartForge Infrastructure"
echo "======================================="

############################################
# ECS SERVICE
############################################

echo "Checking ECS Service..."

SERVICE_STATUS=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$AWS_REGION" \
    --query 'services[0].status' \
    --output text 2>/dev/null || echo "MISSING")

if [[ "$SERVICE_STATUS" != "MISSING" && "$SERVICE_STATUS" != "INACTIVE" ]]; then

    echo "Scaling service to 0..."

    aws ecs update-service \
        --cluster "$CLUSTER_NAME" \
        --service "$SERVICE_NAME" \
        --desired-count 0 \
        --region "$AWS_REGION" >/dev/null || true

    aws ecs wait services-stable \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_NAME" \
        --region "$AWS_REGION" || true

    echo "Deleting service..."

    aws ecs delete-service \
        --cluster "$CLUSTER_NAME" \
        --service "$SERVICE_NAME" \
        --force \
        --region "$AWS_REGION" >/dev/null || true
fi

############################################
# TASK DEFINITIONS
############################################

echo "Deleting task definitions..."

TASKS=$(aws ecs list-task-definitions \
    --family-prefix "$TASK_FAMILY" \
    --region "$AWS_REGION" \
    --query 'taskDefinitionArns[]' \
    --output text)

for TASK in $TASKS
do
    echo "Removing $TASK"
    aws ecs deregister-task-definition \
        --task-definition "$TASK" \
        --region "$AWS_REGION" >/dev/null || true
done

############################################
# LOAD BALANCER
############################################

echo "Checking ALB..."

ALB_ARN=$(aws elbv2 describe-load-balancers \
    --names "$ALB_NAME" \
    --region "$AWS_REGION" \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text 2>/dev/null || echo "")

if [[ -n "$ALB_ARN" && "$ALB_ARN" != "None" ]]; then

    LISTENERS=$(aws elbv2 describe-listeners \
        --load-balancer-arn "$ALB_ARN" \
        --region "$AWS_REGION" \
        --query 'Listeners[].ListenerArn' \
        --output text)

    for LISTENER in $LISTENERS
    do
        echo "Deleting Listener..."
        aws elbv2 delete-listener \
            --listener-arn "$LISTENER" \
            --region "$AWS_REGION" || true
    done

    echo "Deleting ALB..."

    aws elbv2 delete-load-balancer \
        --load-balancer-arn "$ALB_ARN" \
        --region "$AWS_REGION" || true

    echo "Waiting for ALB deletion..."

    aws elbv2 wait load-balancers-deleted \
        --load-balancer-arns "$ALB_ARN" \
        --region "$AWS_REGION" || true
fi

############################################
# TARGET GROUP
############################################

echo "Deleting Target Group..."

TG_ARN=$(aws elbv2 describe-target-groups \
    --names "$TG_NAME" \
    --region "$AWS_REGION" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text 2>/dev/null || echo "")

if [[ -n "$TG_ARN" && "$TG_ARN" != "None" ]]; then

    aws elbv2 delete-target-group \
        --target-group-arn "$TG_ARN" \
        --region "$AWS_REGION" || true
fi

############################################
# CLOUDWATCH ALARM
############################################

echo "Deleting CloudWatch Alarm..."

aws cloudwatch delete-alarms \
    --alarm-names "$ALARM_NAME" \
    --region "$AWS_REGION" || true

############################################
# ECS CLUSTER
############################################

echo "Deleting ECS Cluster..."

aws ecs delete-cluster \
    --cluster "$CLUSTER_NAME" \
    --region "$AWS_REGION" || true

############################################
# ECR
############################################

echo "Deleting ECR Repository..."

aws ecr delete-repository \
    --repository-name "$ECR_REPO_NAME" \
    --force \
    --region "$AWS_REGION" || true

############################################
# IAM ROLE
############################################

echo "Deleting IAM Role..."

aws iam detach-role-policy \
    --role-name "$EXEC_ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy \
    >/dev/null 2>&1 || true

aws iam delete-role \
    --role-name "$EXEC_ROLE_NAME" \
    >/dev/null 2>&1 || true

echo ""
echo "======================================="
echo "Cleanup Completed Successfully"
echo "======================================="
