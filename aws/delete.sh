#!/usr/bin/env bash
set -e

AWS_REGION="us-east-1"

CLUSTER_NAME="cartforge-cluster"
SERVICE_NAME="cartforge-service"
TASK_FAMILY="cartforge-task"

ALB_NAME="cartforge-alb"
TG_NAME="cartforge-tg"

ECR_REPO_NAME="cartforge"

ALARM_NAME="cartforge-5xx-alarm"

echo "Deleting ECS Service..."

aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --desired-count 0 \
    --region $AWS_REGION || true

sleep 10

aws ecs delete-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --force \
    --region $AWS_REGION || true

echo "Waiting for service deletion..."

while true
do
    STATUS=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services $SERVICE_NAME \
        --region $AWS_REGION \
        --query 'services[0].status' \
        --output text 2>/dev/null || echo "MISSING")

    if [ "$STATUS" = "INACTIVE" ] || [ "$STATUS" = "MISSING" ]; then
        break
    fi

    sleep 5
done

echo "Deleting Task Definitions..."

TASKS=$(aws ecs list-task-definitions \
    --family-prefix $TASK_FAMILY \
    --region $AWS_REGION \
    --query 'taskDefinitionArns[]' \
    --output text)

for task in $TASKS
do
    aws ecs deregister-task-definition \
        --task-definition $task \
        --region $AWS_REGION || true
done

echo "Deleting Listener..."

LISTENER=$(aws elbv2 describe-listeners \
    --load-balancer-arn $(aws elbv2 describe-load-balancers \
        --names $ALB_NAME \
        --region $AWS_REGION \
        --query 'LoadBalancers[0].LoadBalancerArn' \
        --output text) \
    --region $AWS_REGION \
    --query 'Listeners[0].ListenerArn' \
    --output text 2>/dev/null || true)

if [ "$LISTENER" != "None" ]; then
    aws elbv2 delete-listener \
        --listener-arn $LISTENER
fi

echo "Deleting Load Balancer..."

aws elbv2 delete-load-balancer \
    --name $ALB_NAME \
    --region $AWS_REGION || true

echo "Waiting for ALB deletion..."

sleep 30

echo "Deleting Target Group..."

TG=$(aws elbv2 describe-target-groups \
    --names $TG_NAME \
    --region $AWS_REGION \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text 2>/dev/null || true)

if [ "$TG" != "None" ]; then
    aws elbv2 delete-target-group \
        --target-group-arn $TG
fi

echo "Deleting CloudWatch Alarm..."

aws cloudwatch delete-alarms \
    --alarm-names $ALARM_NAME \
    --region $AWS_REGION || true

echo "Deleting ECS Cluster..."

aws ecs delete-cluster \
    --cluster $CLUSTER_NAME \
    --region $AWS_REGION || true

echo "Deleting ECR Repository..."

aws ecr delete-repository \
    --repository-name $ECR_REPO_NAME \
    --force \
    --region $AWS_REGION || true

echo ""
echo "Cleanup Completed."
