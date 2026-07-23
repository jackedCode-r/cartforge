#!/usr/bin/env bash
# Idempotent provisioning script - no CodeDeploy (not available on AWS
# Educate / some free-tier student accounts). Uses a single target group
# and plain ECS rolling deployments with the built-in deployment circuit
# breaker for automatic rollback instead.
# Safe to run top-to-bottom, and safe to re-run after a partial failure -
# every resource is checked first and only created if it doesn't exist.
#
# Usage:
#   aws configure   # once, with your access key / secret / region
#   chmod +x provision.sh
#   ./provision.sh
set -euo pipefail

AWS_REGION="us-east-1"
VPC_ID="vpc-06df35f7d668b64a1"
SUBNET_IDS="subnet-0b4b36ab3e084c5f2,subnet-0b5fed250cf90265a,subnet-03842953cc80edc98"
SG_ID="sg-0a53e7118605951de"

CLUSTER_NAME="cartforge-cluster"
SERVICE_NAME="cartforge-service"
ALB_NAME="cartforge-alb"
ECR_REPO_NAME="cartforge"
TASK_FAMILY="cartforge-task"
CONTAINER_NAME="cartforge"
CONTAINER_PORT=80
TG_NAME="cartforge-tg"
ALARM_NAME="cartforge-5xx-alarm"
EXEC_ROLE_NAME="ecsTaskExecutionRole"
TASKDEF_TEMPLATE="taskdef.json"

log()  { echo -e "\033[1;34m==>\033[0m $*" >&2; }
ok()   { echo -e "\033[1;32m[skip, exists]\033[0m $*" >&2; }
made() { echo -e "\033[1;33m[created]\033[0m $*" >&2; }

# ---------------------------------------------------------------------------
# 0. Resolve account ID up front
# ---------------------------------------------------------------------------
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
log "AWS account: $AWS_ACCOUNT_ID | region: $AWS_REGION"

# ---------------------------------------------------------------------------
# 1. ECR repository
# ---------------------------------------------------------------------------
log "ECR repository: $ECR_REPO_NAME"
if aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    ok "ECR repository $ECR_REPO_NAME"
else
    aws ecr create-repository --repository-name "$ECR_REPO_NAME" --region "$AWS_REGION" >/dev/null
    made "ECR repository $ECR_REPO_NAME"
fi
ECR_URI=$(aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" \
    --region "$AWS_REGION" --query 'repositories[0].repositoryUri' --output text)
echo "    URI: $ECR_URI"

# ---------------------------------------------------------------------------
# 2. IAM role - only ecsTaskExecutionRole is needed now (no CodeDeployECSRole)
# ---------------------------------------------------------------------------
log "IAM role: $EXEC_ROLE_NAME"
if aws iam get-role --role-name "$EXEC_ROLE_NAME" >/dev/null 2>&1; then
    ok "IAM role $EXEC_ROLE_NAME"
else
    aws iam create-role --role-name "$EXEC_ROLE_NAME" \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {"Service": "ecs-tasks.amazonaws.com"},
                "Action": "sts:AssumeRole"
            }]
        }' >/dev/null
    aws iam attach-role-policy --role-name "$EXEC_ROLE_NAME" \
        --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
    made "IAM role $EXEC_ROLE_NAME"
fi
EXEC_ROLE_ARN=$(aws iam get-role --role-name "$EXEC_ROLE_NAME" --query 'Role.Arn' --output text)

# ---------------------------------------------------------------------------
# 3. ECS cluster
# ---------------------------------------------------------------------------
log "ECS cluster: $CLUSTER_NAME"
CLUSTER_STATUS=$(aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$AWS_REGION" \
    --query 'clusters[0].status' --output text 2>/dev/null || echo "MISSING")
if [ "$CLUSTER_STATUS" == "ACTIVE" ]; then
    ok "ECS cluster $CLUSTER_NAME"
else
    aws ecs create-cluster --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" >/dev/null
    made "ECS cluster $CLUSTER_NAME"
fi

# ---------------------------------------------------------------------------
# 4. Single target group (no blue/green pair needed without CodeDeploy)
# ---------------------------------------------------------------------------
log "Target group: $TG_NAME"
if aws elbv2 describe-target-groups --names "$TG_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    ok "Target group $TG_NAME"
else
    aws elbv2 create-target-group \
        --name "$TG_NAME" --protocol HTTP --port "$CONTAINER_PORT" \
        --vpc-id "$VPC_ID" --target-type ip \
        --health-check-path "/health" \
        --region "$AWS_REGION" >/dev/null
    made "Target group $TG_NAME"
fi
TG_ARN=$(aws elbv2 describe-target-groups --names "$TG_NAME" --region "$AWS_REGION" \
    --query 'TargetGroups[0].TargetGroupArn' --output text)

# ---------------------------------------------------------------------------
# 5. Application Load Balancer + listener
# ---------------------------------------------------------------------------
log "Load balancer: $ALB_NAME"
if aws elbv2 describe-load-balancers --names "$ALB_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    ok "Load balancer $ALB_NAME"
else
    IFS=',' read -ra SUBNET_ARR <<< "$SUBNET_IDS"
    aws elbv2 create-load-balancer \
        --name "$ALB_NAME" --subnets "${SUBNET_ARR[@]}" \
        --security-groups "$SG_ID" --region "$AWS_REGION" >/dev/null
    made "Load balancer $ALB_NAME"
    log "Waiting for load balancer to become active..."
    aws elbv2 wait load-balancer-available --names "$ALB_NAME" --region "$AWS_REGION"
fi
ALB_ARN=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --region "$AWS_REGION" \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text)
ALB_DNS=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --region "$AWS_REGION" \
    --query 'LoadBalancers[0].DNSName' --output text)
ALB_ARN_SUFFIX=$(echo "$ALB_ARN" | sed -E 's#.*(app/[^/]+/[^/]+)$#\1#')

log "Listener on $ALB_NAME (port 80 -> $TG_NAME)"
LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --region "$AWS_REGION" \
    --query "Listeners[?Port==\`80\`].ListenerArn | [0]" --output text 2>/dev/null || echo "None")
if [ "$LISTENER_ARN" != "None" ] && [ -n "$LISTENER_ARN" ]; then
    ok "Listener on port 80"
else
    LISTENER_ARN=$(aws elbv2 create-listener \
        --load-balancer-arn "$ALB_ARN" --protocol HTTP --port 80 \
        --default-actions "Type=forward,TargetGroupArn=$TG_ARN" \
        --region "$AWS_REGION" --query 'Listeners[0].ListenerArn' --output text)
    made "Listener on port 80"
fi

echo "    ALB DNS:        $ALB_DNS"
echo "    ALB ARN suffix: $ALB_ARN_SUFFIX"

# ---------------------------------------------------------------------------
# 6. ECS task definition (patched with the real image URI + execution role)
# ---------------------------------------------------------------------------
log "Task definition family: $TASK_FAMILY"
EXISTING_REVISION=$(aws ecs list-task-definitions --family-prefix "$TASK_FAMILY" \
    --region "$AWS_REGION" --query 'taskDefinitionArns[-1]' --output text 2>/dev/null || echo "None")

if [ "$EXISTING_REVISION" != "None" ] && [ -n "$EXISTING_REVISION" ]; then
    ok "Task definition $TASK_FAMILY (latest: $EXISTING_REVISION)"
    TASK_DEF_ARN="$EXISTING_REVISION"
else
    if [ ! -f "$TASKDEF_TEMPLATE" ]; then
        echo "Missing $TASKDEF_TEMPLATE - cannot register the task definition." >&2
        exit 1
    fi
    PATCHED_TASKDEF=$(mktemp)
    jq --arg IMAGE "${ECR_URI}:latest" \
       --arg EXEC_ROLE "$EXEC_ROLE_ARN" \
       '.containerDefinitions[0].image = $IMAGE | .executionRoleArn = $EXEC_ROLE' \
       "$TASKDEF_TEMPLATE" > "$PATCHED_TASKDEF"

    TASK_DEF_ARN=$(aws ecs register-task-definition --cli-input-json "file://$PATCHED_TASKDEF" \
        --region "$AWS_REGION" --query 'taskDefinition.taskDefinitionArn' --output text)
    rm -f "$PATCHED_TASKDEF"
    made "Task definition $TASK_FAMILY ($TASK_DEF_ARN)"
fi

# ---------------------------------------------------------------------------
# 7. ECS service - plain rolling deployment, with the deployment circuit
#    breaker enabled. This is the automatic-rollback mechanism: if the new
#    tasks fail to reach a stable healthy state, ECS itself reverts the
#    service to the previous task definition. No CodeDeploy required.
# ---------------------------------------------------------------------------
log "ECS service: $SERVICE_NAME"
SERVICE_STATUS=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" \
    --region "$AWS_REGION" --query 'services[0].status' --output text 2>/dev/null || echo "MISSING")

if [ "$SERVICE_STATUS" == "ACTIVE" ]; then
    ok "ECS service $SERVICE_NAME"
else
    NETWORK_CONFIG="awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SG_ID],assignPublicIp=ENABLED}"
    aws ecs create-service \
        --cluster "$CLUSTER_NAME" \
        --service-name "$SERVICE_NAME" \
        --task-definition "$TASK_DEF_ARN" \
        --desired-count 2 \
        --launch-type FARGATE \
        --network-configuration "$NETWORK_CONFIG" \
        --load-balancers "targetGroupArn=$TG_ARN,containerName=$CONTAINER_NAME,containerPort=$CONTAINER_PORT" \
        --deployment-configuration "deploymentCircuitBreaker={enable=true,rollback=true},maximumPercent=200,minimumHealthyPercent=100" \
        --region "$AWS_REGION" >/dev/null
    made "ECS service $SERVICE_NAME"
fi

# ---------------------------------------------------------------------------
# 8. CloudWatch alarm - informational only now (no CodeDeploy to react to
#    it automatically). Set up an SNS topic + email subscription if you
#    want to be paged when it fires; otherwise just watch it in the console
#    during Phase 9-style failure tests.
# ---------------------------------------------------------------------------
log "CloudWatch alarm: $ALARM_NAME"
ALARM_EXISTS=$(aws cloudwatch describe-alarms --alarm-names "$ALARM_NAME" --region "$AWS_REGION" \
    --query 'MetricAlarms[0].AlarmName' --output text 2>/dev/null || echo "None")
if [ "$ALARM_EXISTS" == "$ALARM_NAME" ]; then
    ok "CloudWatch alarm $ALARM_NAME"
else
    aws cloudwatch put-metric-alarm \
        --alarm-name "$ALARM_NAME" \
        --namespace AWS/ApplicationELB \
        --metric-name HTTPCode_Target_5XX_Count \
        --dimensions "Name=LoadBalancer,Value=$ALB_ARN_SUFFIX" \
        --statistic Sum \
        --period 60 \
        --evaluation-periods 2 \
        --threshold 5 \
        --comparison-operator GreaterThanThreshold \
        --treat-missing-data notBreaching \
        --region "$AWS_REGION"
    made "CloudWatch alarm $ALARM_NAME"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=================================================================="
echo " Done. Values to paste into your Jenkinsfile / notes:"
echo "=================================================================="
echo " AWS_ACCOUNT_ID   = $AWS_ACCOUNT_ID"
echo " ECR_URI          = $ECR_URI"
echo " ALB_DNS          = $ALB_DNS"
echo " ALB_ARN_SUFFIX   = $ALB_ARN_SUFFIX"
echo " TG_ARN           = $TG_ARN"
echo " EXEC_ROLE_ARN    = $EXEC_ROLE_ARN"
echo " TASK_DEF_ARN     = $TASK_DEF_ARN"
echo "=================================================================="