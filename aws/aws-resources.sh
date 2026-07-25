#!/usr/bin/env bash
# Idempotent provisioning script - safe to run top-to-bottom, and safe to
# re-run after a partial failure. Every resource is checked first; it's
# only created if it doesn't already exist. ARNs (target groups, listener,
# IAM roles, ECR URI, account ID) are looked up automatically instead of
# being hardcoded as placeholders.
#
# Usage:
#   aws configure   # once, with your access key / secret / region
#   chmod +x provision.sh
#   ./provision.sh
set -euo pipefail

AWS_REGION="us-east-1"
VPC_ID="vpc-0c4b5560433c9b0fe"
SUBNET_IDS="subnet-0bc5a1ba7779ce97a,subnet-066c61423823932e5,subnet-0b895ff01ad9df2fb"
SG_ID="sg-045f1c24a0d92e879"

CLUSTER_NAME="cartforge-cluster"
SERVICE_NAME="cartforge-service"
ALB_NAME="cartforge-alb"
ECR_REPO_NAME="cartforge"
TASK_FAMILY="cartforge-task"
CONTAINER_NAME="cartforge"
CONTAINER_PORT=80
TG_BLUE_NAME="cartforge-tg-blue"
TG_GREEN_NAME="cartforge-tg-green"
CODEDEPLOY_APP="cartforge-app"
CODEDEPLOY_GROUP="cartforge-deployment-group"
CODEDEPLOY_CONFIG="CodeDeployDefault.ECSCanary10Percent5Minutes"
ALARM_NAME="cartforge-5xx-alarm"
EXEC_ROLE_NAME="ecsTaskExecutionRole"
DEPLOY_ROLE_NAME="CodeDeployECSRole"
TASKDEF_TEMPLATE="taskdef.json"   # must contain a placeholder "<IMAGE_URI>" for the image field

log()  { echo -e "\033[1;34m==>\033[0m $*" >&2; }
ok()   { echo -e "\033[1;32m[skip, exists]\033[0m $*" >&2; }
made() { echo -e "\033[1;33m[created]\033[0m $*" >&2; }
# ---------------------------------------------------------------------------
# 0. Resolve account ID up front - everything else derives from this
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
# 2. IAM roles (ecsTaskExecutionRole, CodeDeployECSRole)
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

log "IAM role: $DEPLOY_ROLE_NAME"
if aws iam get-role --role-name "$DEPLOY_ROLE_NAME" >/dev/null 2>&1; then
    ok "IAM role $DEPLOY_ROLE_NAME"
else
    aws iam create-role --role-name "$DEPLOY_ROLE_NAME" \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {"Service": "codedeploy.amazonaws.com"},
                "Action": "sts:AssumeRole"
            }]
        }' >/dev/null
    aws iam attach-role-policy --role-name "$DEPLOY_ROLE_NAME" \
        --policy-arn arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS
    made "IAM role $DEPLOY_ROLE_NAME"
fi
DEPLOY_ROLE_ARN=$(aws iam get-role --role-name "$DEPLOY_ROLE_NAME" --query 'Role.Arn' --output text)

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
# 4. Target groups (blue & green)
# ---------------------------------------------------------------------------
create_target_group_if_missing() {
    local NAME=$1
    if aws elbv2 describe-target-groups --names "$NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
        ok "Target group $NAME"
    else
        aws elbv2 create-target-group \
            --name "$NAME" --protocol HTTP --port "$CONTAINER_PORT" \
            --vpc-id "$VPC_ID" --target-type ip \
            --health-check-path "/health" \
            --region "$AWS_REGION" >/dev/null
        made "Target group $NAME"
    fi
    aws elbv2 describe-target-groups --names "$NAME" --region "$AWS_REGION" \
        --query 'TargetGroups[0].TargetGroupArn' --output text
}

log "Target groups: $TG_BLUE_NAME / $TG_GREEN_NAME"
TG_BLUE_ARN=$(create_target_group_if_missing "$TG_BLUE_NAME")
TG_GREEN_ARN=$(create_target_group_if_missing "$TG_GREEN_NAME")

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
# ARN suffix is everything after the account ID segment, e.g. app/cartforge-alb/1234567890abcdef
ALB_ARN_SUFFIX=$(echo "$ALB_ARN" | sed -E 's#.*(app/[^/]+/[^/]+)$#\1#')

log "Listener on $ALB_NAME (port 80 -> $TG_BLUE_NAME)"
LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --region "$AWS_REGION" \
    --query "Listeners[?Port==\`80\`].ListenerArn | [0]" --output text 2>/dev/null || echo "None")
if [ "$LISTENER_ARN" != "None" ] && [ -n "$LISTENER_ARN" ]; then
    ok "Listener on port 80"
else
    LISTENER_ARN=$(aws elbv2 create-listener \
        --load-balancer-arn "$ALB_ARN" --protocol HTTP --port 80 \
        --default-actions "Type=forward,TargetGroupArn=$TG_BLUE_ARN" \
        --region "$AWS_REGION" --query 'Listeners[0].ListenerArn' --output text)
    made "Listener on port 80"
fi

echo "    ALB DNS:        $ALB_DNS"
echo "    ALB ARN suffix: $ALB_ARN_SUFFIX"
echo "    Listener ARN:   $LISTENER_ARN"

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
# 7. ECS service (CodeDeploy-controlled, blue/green)
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
        --deployment-controller type=CODE_DEPLOY \
        --network-configuration "$NETWORK_CONFIG" \
        --load-balancers "targetGroupArn=$TG_BLUE_ARN,containerName=$CONTAINER_NAME,containerPort=$CONTAINER_PORT" \
        --region "$AWS_REGION" >/dev/null
    made "ECS service $SERVICE_NAME"
fi

# ---------------------------------------------------------------------------
# 8. CloudWatch alarm (rollback trigger)
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
# 9. CodeDeploy application
# ---------------------------------------------------------------------------
log "CodeDeploy application: $CODEDEPLOY_APP"
if aws deploy get-application --application-name "$CODEDEPLOY_APP" --region "$AWS_REGION" >/dev/null 2>&1; then
    ok "CodeDeploy application $CODEDEPLOY_APP"
else
    aws deploy create-application \
        --application-name "$CODEDEPLOY_APP" \
        --compute-platform ECS \
        --region "$AWS_REGION" >/dev/null
    made "CodeDeploy application $CODEDEPLOY_APP"
fi

# ---------------------------------------------------------------------------
# 10. CodeDeploy deployment group (canary + alarm + auto-rollback)
# ---------------------------------------------------------------------------
log "CodeDeploy deployment group: $CODEDEPLOY_GROUP"
if aws deploy get-deployment-group --application-name "$CODEDEPLOY_APP" \
    --deployment-group-name "$CODEDEPLOY_GROUP" --region "$AWS_REGION" >/dev/null 2>&1; then
    ok "CodeDeploy deployment group $CODEDEPLOY_GROUP"
else
    aws deploy create-deployment-group \
        --application-name "$CODEDEPLOY_APP" \
        --deployment-group-name "$CODEDEPLOY_GROUP" \
        --deployment-config-name "$CODEDEPLOY_CONFIG" \
        --service-role-arn "$DEPLOY_ROLE_ARN" \
        --ecs-services "clusterName=$CLUSTER_NAME,serviceName=$SERVICE_NAME" \
        --auto-rollback-configuration "enabled=true,events=DEPLOYMENT_FAILURE,DEPLOYMENT_STOP_ON_ALARM" \
        --alarm-configuration "enabled=true,alarms=[{name=$ALARM_NAME}]" \
        --load-balancer-info "targetGroupPairInfoList=[{targetGroups=[{name=$TG_BLUE_NAME},{name=$TG_GREEN_NAME}],prodTrafficRoute={listenerArns=[$LISTENER_ARN]}}]" \
        --region "$AWS_REGION" >/dev/null
    made "CodeDeploy deployment group $CODEDEPLOY_GROUP"
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
echo " LISTENER_ARN     = $LISTENER_ARN"
echo " TG_BLUE_ARN      = $TG_BLUE_ARN"
echo " TG_GREEN_ARN     = $TG_GREEN_ARN"
echo " EXEC_ROLE_ARN    = $EXEC_ROLE_ARN"
echo " DEPLOY_ROLE_ARN  = $DEPLOY_ROLE_ARN"
echo " TASK_DEF_ARN     = $TASK_DEF_ARN"
echo "=================================================================="