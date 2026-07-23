# CartForge — AWS Console Setup Guide (no CLI, click-by-click)

This walks through creating every AWS resource for CartForge's pipeline
**using the AWS Console UI only** — no `aws` CLI commands. Do the steps in
order; later steps need names/values from earlier ones, so keep this page
open and fill in the **"Your values"** table as you go.

**Region used throughout:** `us-east-1` (N. Virginia) — make sure the region
selector in the top-right of the AWS Console is set to this before starting
every single step below. Picking resources in the wrong region is the #1
cause of "it says not found" errors.

---

## Your values (fill this in as you go)

| Name | Value |
|---|---|
| AWS Region | `us-east-1` |
| VPC ID | `vpc-06df35f7d668b64a1` |
| Subnet IDs | `subnet-0b4b36ab3e084c5f2`, `subnet-0b5fed250cf90265a`, `subnet-03842953cc80edc98` |
| Security Group ID | `sg-0a53e7118605951de` |
| AWS Account ID | *(top-right of console, click your name)* |
| ECR repository URI | *(you'll get this in Step 1)* |
| ecsTaskExecutionRole ARN | *(Step 2)* |
| CodeDeployECSRole ARN | *(Step 2)* |
| Blue target group ARN | *(Step 4)* |
| Green target group ARN | *(Step 4)* |
| ALB ARN / Listener ARN | *(Step 5)* |
| ALB ARN suffix (for the alarm) | *(Step 5)* |

---

## Step 1 — Create the ECR repository

1. Console search bar → type **ECR** → open **Elastic Container Registry**
2. Left sidebar → **Repositories** → **Create repository**
3. Visibility: **Private**
4. Repository name: `cartforge`
5. Leave "Tag immutability" off, "Scan on push" **ON** (free extra vulnerability scan on top of Trivy)
6. Click **Create repository**
7. Click into the new repo → copy the **URI** shown at the top
   (looks like `123456789012.dkr.ecr.us-east-1.amazonaws.com/cartforge`) —
   save it in the table above, Jenkins needs it.

**✅ Check:** the repo shows up in the repository list with 0 images.

---

## Step 2 — Create the two IAM roles

You need two roles: one lets ECS pull your image and write logs, the other
lets CodeDeploy manage ECS deployments on your behalf.

### 2a. `ecsTaskExecutionRole`

1. Console search bar → **IAM** → **Roles** (left sidebar) → **Create role**
2. Trusted entity type: **AWS service**
3. Use case: search **Elastic Container Service** → select
   **Elastic Container Service Task**
4. Click **Next**
5. On the permissions page, search and check:
   **`AmazonECSTaskExecutionRolePolicy`**
6. Click **Next**
7. Role name: `ecsTaskExecutionRole`
8. Click **Create role**
9. Click into the role you just made → copy the **ARN** at the top → save it

### 2b. `CodeDeployECSRole`

1. IAM → **Roles** → **Create role**
2. Trusted entity type: **AWS service**
3. Use case: search **CodeDeploy** → select **CodeDeploy - ECS**
4. Click **Next** — the correct policy
   (`AWSCodeDeployRoleForECS`) is auto-attached, just confirm it's checked
5. Click **Next**
6. Role name: `CodeDeployECSRole`
7. Click **Create role**
8. Click into it → copy the **ARN** → save it

**✅ Check:** IAM → Roles shows both `ecsTaskExecutionRole` and
`CodeDeployECSRole` in the list.

---

## Step 3 — Create the ECS cluster

1. Console search bar → **ECS** → **Elastic Container Service**
2. Left sidebar → **Clusters** → **Create cluster**
3. Cluster name: `cartforge-cluster`
4. Infrastructure: check **AWS Fargate (serverless)** only (uncheck EC2/external if shown)
5. Leave networking/monitoring defaults
6. Click **Create**

**✅ Check:** the cluster appears with status **Active** (takes ~30 seconds).

---

## Step 4 — Create two target groups (blue & green)

These are what CodeDeploy flips traffic between during a canary release.

### 4a. Blue target group

1. Console search bar → **EC2** → left sidebar, under **Load Balancing** →
   **Target Groups** → **Create target group**
2. Target type: **IP addresses** (required for Fargate)
3. Target group name: `cartforge-tg-blue`
4. Protocol: **HTTP**, Port: **80**
5. VPC: select `vpc-06df35f7d668b64a1`
6. Protocol version: HTTP1
7. Health check path: `/health` (matches the nginx config that serves the app)
8. Click **Next** → don't register any targets yet (ECS does this
   automatically) → **Create target group**
9. Click into it → copy the **ARN** → save it

### 4b. Green target group

Repeat the exact same steps, name it `cartforge-tg-green` instead. Copy its
ARN too.

**✅ Check:** EC2 → Target Groups shows both `cartforge-tg-blue` and
`cartforge-tg-green`, both currently with 0 healthy targets (expected —
nothing's deployed yet).

---

## Step 5 — Create the Application Load Balancer

1. EC2 → **Load Balancers** (under Load Balancing) → **Create load balancer**
2. Choose **Application Load Balancer** → **Create**
3. Name: `cartforge-alb`
4. Scheme: **Internet-facing**
5. IP address type: IPv4
6. VPC: `vpc-06df35f7d668b64a1`
7. Mappings: check **all three** availability zones matching your subnets
   (`subnet-0b4b36ab3e084c5f2`, `subnet-0b5fed250cf90265a`,
   `subnet-03842953cc80edc98`) — pick each one from its AZ's dropdown
8. Security groups: remove the default one if pre-selected, add
   `sg-0a53e7118605951de`
9. Listeners and routing: Protocol **HTTP**, Port **80**, default action →
   **Forward to** → select `cartforge-tg-blue`
10. Click **Create load balancer**

Once it's created (status **Active**, takes 1-2 minutes):

11. Click into the ALB → **DNS name** shown near the top — this is your
    app's public URL once something is deployed. Save it.
12. Click the **Listeners** tab → click the listener (port 80) → copy its
    **ARN** → save it as "Listener ARN"
13. Back on the ALB's main page, copy the **ARN** shown at the top → the
    part after the last `/` before the ID (e.g.
    `app/cartforge-alb/1234567890abcdef`) is the **ARN suffix** you'll need
    for the CloudWatch alarm in Step 8 — save it.

**✅ Check:** ALB status is **Active** and its DNS name resolves in a
browser (it'll show a "503 Service Temporarily Unavailable" — expected,
since ECS has no running tasks registered to the blue target group yet).

---

## Step 6 — Register the ECS task definition

1. ECS → left sidebar → **Task definitions** → **Create new task definition**
2. Task definition family: `cartforge-task`
3. Launch type: **AWS Fargate**
4. Operating system: Linux/X86_64
5. Task size: CPU **0.25 vCPU**, Memory **0.5 GB** (fine for this project)
6. Task role: leave as **None**
7. Task execution role: select **`ecsTaskExecutionRole`** (the one from Step 2a)
8. Container details:
   - Container name: `cartforge`
   - Image URI: paste the ECR URI from Step 1, tag `:latest`
     (e.g. `123456789012.dkr.ecr.us-east-1.amazonaws.com/cartforge:latest`)
     — this won't have an image pushed yet, that's fine, Jenkins pushes the
     first real one later
   - Container port: `80`, protocol TCP, App protocol HTTP
9. Under **Logging**, leave "Use log collection" checked — it creates the
   CloudWatch log group `/ecs/cartforge-task` automatically
10. Click **Create**

**✅ Check:** the task definition appears with revision **1**.

---

## Step 7 — Create the ECS service (with CodeDeploy as the deployment controller)

This is the step that connects ECS to CodeDeploy for canary deployments —
pay close attention to the deployment options.

1. ECS → **Clusters** → click `cartforge-cluster` → **Services** tab → **Create**
2. Compute options: **Launch type** → **FARGATE**
3. Deployment configuration:
   - Application type: **Service**
   - Family: `cartforge-task`, Revision: **latest**
   - Service name: `cartforge-service`
   - Desired tasks: `2`
4. **Deployment options** → Deployment type: select
   **Blue/Green deployment** — this is what wires the service to CodeDeploy
   instead of ECS's own rolling update. Under it:
   - Application name: leave the default suggestion, or type
     `cartforge-app` (must match what you'll name the CodeDeploy app in Step 10)
   - Deployment group name: `cartforge-deployment-group`
   - Service role: select **`CodeDeployECSRole`** (Step 2b)
5. **Networking**:
   - VPC: `vpc-06df35f7d668b64a1`
   - Subnets: select all three subnet IDs from the table above
   - Security group: select `sg-0a53e7118605951de`
   - Public IP: **Turned on**
6. **Load balancing**:
   - Load balancer type: **Application Load Balancer**
   - Load balancer: select `cartforge-alb`
   - Container to load balance: `cartforge:80`
   - Production listener: select the port 80 listener
   - Target group 1 (production): `cartforge-tg-blue`
   - Target group 2 (test/green): `cartforge-tg-green`
7. Leave Service Auto Scaling off for now (add later once this all works)
8. Click **Create**

**✅ Check:** ECS → cartforge-cluster → Services shows `cartforge-service`
with status **Active**. Running count may show 0/2 until the first image
exists in ECR — that's expected until Jenkins runs.

---

## Step 8 — Create the CloudWatch alarm (rollback trigger)

1. Console search bar → **CloudWatch**
2. Left sidebar → **Alarms** → **All alarms** → **Create alarm**
3. **Select metric** → **Browse** → **ApplicationELB** → **Per AppELB Metrics**
4. Find your load balancer (matches the ARN suffix you saved in Step 5) →
   check **HTTPCode_Target_5XX_Count** → click **Select metric**
5. Metric settings:
   - Statistic: **Sum**
   - Period: **1 minute**
6. Conditions:
   - Threshold type: **Static**
   - Whenever HTTPCode_Target_5XX_Count is: **Greater than** `5`
7. Additional configuration → Datapoints to alarm: `2 out of 2`
8. Click **Next** (you can skip SNS notification, or add your email if you
   want to be paged too — CodeDeploy watches the alarm state directly, it
   doesn't need the notification to work)
9. Alarm name: `cartforge-5xx-alarm`
10. Click **Next** → **Create alarm**

**✅ Check:** CloudWatch → Alarms shows `cartforge-5xx-alarm` with state
**Insufficient data** or **OK** (both fine — it just means no 5xx spike has
happened yet).

---

## Step 9 — Create the CodeDeploy application

1. Console search bar → **CodeDeploy**
2. Left sidebar → **Applications** → **Create application**
3. Application name: `cartforge-app`
4. Compute platform: **Amazon ECS**
5. Click **Create application**

**✅ Check:** it appears in the Applications list.

---

## Step 10 — Create the CodeDeploy deployment group (canary + alarm + rollback)

This is where the canary percentage and automatic rollback are actually configured.

1. Inside the `cartforge-app` you just created → **Create deployment group**
2. Deployment group name: `cartforge-deployment-group`
3. Service role: select **`CodeDeployECSRole`**
4. Environment configuration:
   - ECS cluster name: `cartforge-cluster`
   - ECS service name: `cartforge-service`
5. Load balancer:
   - Check **Use a load balancer**
   - Choose **Application Load Balancer or Network Load Balancer**
   - Production listener port: select your port 80 listener
   - Target group 1 name (production): `cartforge-tg-blue`
   - Target group 2 name (test): `cartforge-tg-green`
6. **Deployment settings**:
   - Deployment configuration: select
     **`CodeDeployDefault.ECSCanary10Percent5Minutes`**
     (this shifts 10% of traffic to the new version, waits 5 minutes, then
     shifts the rest — if nothing tripped the alarm)
7. **Rollbacks**:
   - Check **Roll back when a deployment fails**
   - Check **Roll back when alarm thresholds are met**
8. **Alarms**:
   - Check **Enable CloudWatch alarms**
   - Select `cartforge-5xx-alarm` (from Step 8)
9. Click **Create deployment group**

**✅ Check:** the deployment group shows up under `cartforge-app`, with
"Canary10Percent5Minutes" as its deployment config and the alarm attached.

---

## Step 11 — Final verification checklist

Go through this list before pointing Jenkins at any of it:

- [ ] ECR repo `cartforge` exists, URI saved
- [ ] `ecsTaskExecutionRole` and `CodeDeployECSRole` both exist, ARNs saved
- [ ] ECS cluster `cartforge-cluster` is **Active**
- [ ] Both target groups (`cartforge-tg-blue`, `cartforge-tg-green`) exist, ARNs saved
- [ ] ALB `cartforge-alb` is **Active**, DNS name and listener ARN saved
- [ ] Task definition `cartforge-task` revision 1 exists
- [ ] ECS service `cartforge-service` exists with **Blue/Green (CodeDeploy)** deployment type
- [ ] CloudWatch alarm `cartforge-5xx-alarm` exists
- [ ] CodeDeploy application `cartforge-app` exists
- [ ] CodeDeploy deployment group `cartforge-deployment-group` exists, using
      `CodeDeployDefault.ECSCanary10Percent5Minutes`, with the alarm and
      both rollback checkboxes enabled

Once every box is checked, everything referenced in the `Jenkinsfile`
(`ECS_CLUSTER`, `ECS_SERVICE`, `CODEDEPLOY_APP`, `CODEDEPLOY_GROUP`,
`TASK_DEF_FAMILY`) exists and matches by name — update those environment
values at the top of the `Jenkinsfile` to match exactly what you named
things here, then push to trigger your first pipeline run.