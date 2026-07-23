# CartForge — AWS Console Setup Guide (no CodeDeploy, no CLI)

CodeDeploy-based blue/green isn't available on every AWS free-tier / student
account, so this version skips it entirely. Instead, ECS's own **rolling
deployment** handles the release, and its built-in **deployment circuit
breaker** handles rollback automatically if the new version doesn't come up
healthy — no extra AWS service, no extra cost, works on any account.

**Region used throughout:** `us-east-1` — check the region selector
top-right of the console matches this before every step.

---

## Your values (fill this in as you go)

| Name | Value |
|---|---|
| AWS Region | `us-east-1` |
| VPC ID | `vpc-06df35f7d668b64a1` |
| Subnet IDs | `subnet-0b4b36ab3e084c5f2`, `subnet-0b5fed250cf90265a`, `subnet-03842953cc80edc98` |
| Security Group ID | `sg-0a53e7118605951de` |
| AWS Account ID | *(top-right of console, click your name)* |
| ECR repository URI | *(Step 1)* |
| ecsTaskExecutionRole ARN | *(Step 2)* |
| Target group ARN | *(Step 4)* |
| ALB DNS name / ARN suffix | *(Step 5)* |

---

## Step 1 — Create the ECR repository

1. Console search bar → **ECR** → **Elastic Container Registry**
2. Left sidebar → **Repositories** → **Create repository**
3. Visibility: **Private**, name: `cartforge`
4. "Scan on push": **ON**
5. **Create repository** → click into it → copy the **URI** at the top, save it

**✅ Check:** repo appears in the list with 0 images.

---

## Step 2 — Create the IAM role

Only one role is needed now (no CodeDeploy role).

1. Console search bar → **IAM** → **Roles** → **Create role**
2. Trusted entity type: **AWS service**
3. Use case: search **Elastic Container Service** → select
   **Elastic Container Service Task**
4. **Next** → search and check **`AmazonECSTaskExecutionRolePolicy`**
5. **Next** → Role name: `ecsTaskExecutionRole` → **Create role**
6. Click into it → copy the **ARN** → save it

**✅ Check:** IAM → Roles shows `ecsTaskExecutionRole`.

---

## Step 3 — Create the ECS cluster

1. Console search bar → **ECS** → left sidebar → **Clusters** → **Create cluster**
2. Cluster name: `cartforge-cluster`
3. Infrastructure: check **AWS Fargate (serverless)** only
4. **Create**

**✅ Check:** cluster shows status **Active**.

---

## Step 4 — Create one target group

Only one target group is needed — no blue/green pair, since there's no
CodeDeploy to flip traffic between them.

1. EC2 → left sidebar (Load Balancing) → **Target Groups** → **Create target group**
2. Target type: **IP addresses**
3. Name: `cartforge-tg`
4. Protocol **HTTP**, Port **80**, VPC: `vpc-06df35f7d668b64a1`
5. Health check path: `/health`
6. **Next** → don't register targets yet → **Create target group**
7. Click into it → copy the **ARN** → save it

**✅ Check:** `cartforge-tg` shows in the list, 0 healthy targets (expected — nothing deployed yet).

---

## Step 5 — Create the Application Load Balancer

1. EC2 → **Load Balancers** → **Create load balancer** → **Application Load Balancer** → **Create**
2. Name: `cartforge-alb`, Scheme: **Internet-facing**, IPv4
3. VPC: `vpc-06df35f7d668b64a1`
4. Mappings: check all three AZs matching your subnets
   (`subnet-0b4b36ab3e084c5f2`, `subnet-0b5fed250cf90265a`, `subnet-03842953cc80edc98`)
5. Security groups: use `sg-0a53e7118605951de`
6. Listener: HTTP port 80 → **Forward to** → `cartforge-tg`
7. **Create load balancer**

Once **Active**:

8. Copy the **DNS name** (your app's public URL) → save it
9. Copy the ALB's **ARN** → the part after the account ID
   (e.g. `app/cartforge-alb/1234567890abcdef`) is the **ARN suffix** you'll
   need for the CloudWatch alarm in Step 7 → save it

**✅ Check:** ALB is **Active**; its DNS name shows a 503 in the browser for
now (expected — no running tasks yet).

---

## Step 6 — Register the task definition and create the ECS service

### 6a. Task definition

1. ECS → **Task definitions** → **Create new task definition**
2. Family: `cartforge-task`, Launch type: **AWS Fargate**, Linux/X86_64
3. Task size: 0.25 vCPU / 0.5 GB
4. Task execution role: `ecsTaskExecutionRole`
5. Container: name `cartforge`, image URI = your ECR URI + `:latest`
   (Jenkins will push the real image later), container port `80`
6. Leave log collection on → **Create**

### 6b. ECS service — **this is the step that replaces CodeDeploy**

1. ECS → `cartforge-cluster` → **Services** tab → **Create**
2. Launch type: **FARGATE**
3. Family: `cartforge-task`, revision **latest**, Service name: `cartforge-service`, Desired tasks: `2`
4. **Deployment options** → Deployment type: **Rolling update**
   (this is the plain ECS option — no "Blue/Green" here, since that's the
   CodeDeploy-only path we're skipping)
5. Under **Deployment failure detection**, check
   **"Use deployment circuit breaker with rollback"** — ✅ **this single
   checkbox is what gives you automatic rollback without CodeDeploy.** If
   the new tasks don't reach a healthy steady state, ECS itself reverts the
   service back to the previous task definition.
6. **Networking**: VPC `vpc-06df35f7d668b64a1`, all three subnets,
   security group `sg-0a53e7118605951de`, Public IP **on**
7. **Load balancing**: Application Load Balancer → `cartforge-alb` →
   container `cartforge:80` → listener port 80 → target group `cartforge-tg`
8. **Create**

**✅ Check:** ECS → cartforge-cluster → Services shows `cartforge-service`
**Active**, deployment type "Rolling update", circuit breaker enabled.
Running count may be 0/2 until Jenkins pushes the first image.

---

## Step 7 — Create the CloudWatch alarm (informational)

Without CodeDeploy, this alarm won't trigger a rollback by itself — the
circuit breaker in Step 6b already handles that. This alarm is still worth
having so you (or your monitoring dashboard) can *see* an elevated error
rate happening, and optionally get emailed about it.

1. CloudWatch → **Alarms** → **Create alarm**
2. **Select metric** → **ApplicationELB** → **Per AppELB Metrics** → find
   your load balancer (matches the ARN suffix from Step 5) → check
   **HTTPCode_Target_5XX_Count**
3. Statistic **Sum**, Period **1 minute**
4. Condition: **Greater than** `5`
5. Datapoints to alarm: `2 out of 2`
6. (Optional) **Next** → create/select an SNS topic and add your email so
   you get notified when it fires
7. Alarm name: `cartforge-5xx-alarm` → **Create alarm**

**✅ Check:** alarm appears in CloudWatch → Alarms.

---

## Step 8 — Final verification checklist

- [ ] ECR repo `cartforge` exists, URI saved
- [ ] `ecsTaskExecutionRole` exists, ARN saved
- [ ] ECS cluster `cartforge-cluster` is **Active**
- [ ] Target group `cartforge-tg` exists, ARN saved
- [ ] ALB `cartforge-alb` is **Active**, DNS name and ARN suffix saved
- [ ] Task definition `cartforge-task` revision 1 exists
- [ ] ECS service `cartforge-service` exists, deployment type **Rolling
      update**, with **deployment circuit breaker + rollback enabled**
- [ ] CloudWatch alarm `cartforge-5xx-alarm` exists

Once every box is checked, update the environment values at the top of the
`Jenkinsfile` (`ECS_CLUSTER`, `ECS_SERVICE`, `TASK_DEF_FAMILY`) to match
these names exactly, then push to trigger your first pipeline run.

---

## How rollback actually works now (no CodeDeploy)

Two layers, in order:

1. **ECS deployment circuit breaker** (enabled in Step 6b) — if the tasks
   from the new task definition keep failing their health checks and never
   reach a stable count, ECS stops the rollout on its own and reverts the
   service to the previous task definition. This is automatic and needs
   nothing from Jenkins.
2. **Jenkins fallback rollback** (in the `Jenkinsfile`'s `post { failure }`
   block) — the pipeline records the *current* task definition ARN right
   before deploying. If the `aws ecs wait services-stable` step fails for
   any reason, Jenkins explicitly forces the service back onto that saved
   ARN as a second safety net, in case something failed in a way the
   circuit breaker didn't catch (e.g. the wait command itself timing out).

There's no traffic percentage (10%/50%/100%) without CodeDeploy — new tasks
replace old ones per the rolling update settings (`maximumPercent=200`,
`minimumHealthyPercent=100` in the script/Jenkinsfile), and it's an
all-or-nothing rollback rather than a partial one. That's the trade-off for
not needing CodeDeploy at all.