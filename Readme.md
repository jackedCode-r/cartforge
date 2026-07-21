# CartForge on AWS — a full CI/CD pipeline, step by step
<img width="937" height="593" alt="image" src="https://github.com/user-attachments/assets/a8fe0a96-d19e-4552-bb76-a21166aa6b43" />


**GitHub → Jenkins (build + Gitleaks + Trivy) → ECR → CodeDeploy canary → ECS Fargate → ALB → users**,
with CloudWatch-triggered automatic rollback and Prometheus/Grafana monitoring.

Two diagrams above show the two halves of this: the **CI half** (code → scanned
image) and the **CD half** (canary release → rollback → monitoring). Keep
those in mind as a map while you work through the phases below.

Do the phases in order. Each one builds on the last, and each has a
"you'll know it worked when…" check so you're never guessing.

---

## Phase 0 — What you'll need

- An AWS account (free tier is enough to try this, but ECS/ALB/NAT gateway
  usage isn't fully free — expect a few dollars if you leave it running)
- Your CartForge repo pushed to GitHub
- A laptop with `ssh`, `git`, and the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed
- Basic comfort in a terminal — every command below is copy-pasteable

**Suggested AWS region for this guide:** pick one close to you and use it
everywhere (all the sample files use `ap-south-1` — change it to match yours).

---

## Phase 1 — Launch two EC2 instances

1. **Jenkins master** — Ubuntu 22.04, `t3.medium`, 20GB disk. Security group:
   allow inbound `22` (SSH, from your IP only), `8080` (Jenkins UI, from your
   IP only).
2. **Jenkins agent** — Ubuntu 22.04, `t3.medium`. Security group: allow
   inbound `22` from the Jenkins master's security group only (not the
   whole internet).

Download the `.pem` key pair when you launch each one — you need it for the
very first SSH connection.

**✅ You'll know it worked when:** both instances show `running` in the EC2
console and you can `ssh -i key.pem ubuntu@<ip>` into each one.

---

## Phase 2 — Set up passwordless SSH (`ssh-copy-id`)

Full commands are in **`scripts/ssh-setup-notes.md`**. Short version:

1. On your laptop, generate a key pair (`ssh-keygen -t ed25519`) and
   `ssh-copy-id` it onto the Jenkins master — now you can SSH in without the
   `.pem` file every time.
2. On the Jenkins master, generate a **second** key pair as the `jenkins`
   user, and `ssh-copy-id` *that* onto the Jenkins agent — this is what lets
   Jenkins launch the agent automatically later.

**✅ Check:** `ssh ubuntu@<jenkins-ip>` from your laptop, and
`sudo -u jenkins ssh ubuntu@<agent-ip> echo ok` from the Jenkins master, both
work with no password prompt.

---

## Phase 3 — Install Jenkins, Docker, and the security tools

Copy `scripts/setup-jenkins-ec2.sh` onto the **Jenkins master** and run it:

```bash
scp -i key.pem scripts/setup-jenkins-ec2.sh ubuntu@<jenkins-ip>:~
ssh -i key.pem ubuntu@<jenkins-ip>
chmod +x setup-jenkins-ec2.sh && ./setup-jenkins-ec2.sh
```

It installs: Java, Jenkins, Docker, AWS CLI v2, `jq`, **Trivy** (image
vulnerability scanner), and **Gitleaks** (secret scanner). Run the same
script on the **agent** too, minus Jenkins itself if you want (Docker + AWS
CLI + Trivy + Gitleaks are what actually run the pipeline steps).

At the end it prints Jenkins' initial admin password. Open
`http://<jenkins-ip>:8080`, paste the password in, and install the
**suggested plugins**, then add these specifically (Manage Jenkins > Plugins):

- Docker Pipeline
- Amazon ECR
- Pipeline: AWS Steps / AWS Credentials
- SSH Build Agents

**✅ Check:** Jenkins UI loads, login works, plugins show installed.

---

## Phase 4 — Register the Jenkins agent

Manage Jenkins > Nodes > New Node → follow the steps in
`scripts/ssh-setup-notes.md` §3. This uses the SSH key pair from Phase 2, so
Jenkins can reach the agent without any password stored in plain text.

**✅ Check:** the node shows a green icon (connected) under Manage Jenkins > Nodes.

---

## Phase 5 — Set up AWS resources (ECR, ECS, ALB, CodeDeploy)

This is the biggest one-time setup phase. `ecs/provision-reference-commands.sh`
has every command — go through it top to bottom, filling in your own VPC,
subnet, and security group IDs as you go (it's commented so you know what's
a placeholder). It creates, in order:

1. **ECR repository** — `cartforge` — where Jenkins pushes built images
2. **ECS cluster** (Fargate — no EC2 instances for you to patch)
3. **Application Load Balancer** with **two target groups** (`blue`/`green`)
   — this pair is what makes canary traffic-shifting possible
4. The **initial ECS task definition** (`ecs/taskdef.json` — edit the
   `executionRoleArn` and `image` fields for your account first)
5. The **ECS service**, created with `deploymentController type=CODE_DEPLOY`
   — this one flag is what hands traffic-shifting over to CodeDeploy instead
   of ECS's default rolling update
6. A **CodeDeploy application + deployment group** using
   `CodeDeployDefault.ECSCanary10Percent5Minutes` — AWS's built-in canary
   config: 10% of traffic moves to the new version, waits 5 minutes, then
   the rest moves if nothing's on fire
7. A **CloudWatch alarm** (5xx error count) wired into that deployment
   group — this is the automatic rollback trigger

**✅ Check:** `aws ecs describe-services --cluster cartforge-cluster
--services cartforge-service` shows `"runningCount": 2` and the ALB's DNS
name in your browser shows... nothing yet, since no image has been deployed.
That's expected — Jenkins does that next.

---

## Phase 6 — Wire GitHub to Jenkins

In GitHub: repo Settings > Webhooks > Add webhook →
`http://<jenkins-ip>:8080/github-webhook/`, content type
`application/json`, event: "Just the push event."

In Jenkins: New Item > Pipeline > "Pipeline script from SCM" → point it at
your GitHub repo and the `Jenkinsfile` at its root. Under Build Triggers,
check "GitHub hook trigger for GITScm polling."

Also add your AWS credentials in Jenkins now (Manage Jenkins > Credentials
> System > Global credentials > Add Credentials → kind "AWS Credentials",
ID **`aws-jenkins-creds`** — this exact ID is what `Jenkinsfile` references).
Use an IAM user scoped to just ECR/ECS/CodeDeploy/CloudWatch permissions,
not your root account.

**✅ Check:** pushing an empty commit triggers a build automatically in Jenkins.

---

## Phase 7 — Understand the pipeline (`Jenkinsfile`)

Stages, in order:

1. **Checkout** — pulls your repo
2. **Gitleaks** — scans for committed secrets/API keys; **fails the build
   immediately** if it finds one, before anything is built or pushed
3. **Install & Build** — `npm ci && npm run build` (this always runs)
4. **Docker Build** — builds the image from the root `Dockerfile` (Node
   build stage → nginx serve stage)
5. **Trivy** — scans the built image; **fails on HIGH/CRITICAL**
   vulnerabilities
6. **Push to ECR** — tags with the Jenkins build number and `latest`, pushes both
7. **Register new ECS task definition** — takes the current task def, swaps
   in the new image, registers it as a new revision (old revisions stay
   around — this is what rollback reverts to)
8. **Deploy via CodeDeploy canary** — creates a CodeDeploy deployment, which
   shifts 10% of ALB traffic to the new task, waits, then shifts the rest —
   or stops and reverts automatically if the CloudWatch alarm fires

Stages 4–8 only run if the `USE_DOCKER` build parameter is `true` (the
default). This is the **"run with or without Docker images"** switch you
asked for: set `USE_DOCKER=false` when you just want fast feedback on a
pull request (lint/build/secret-scan only, no image, no deployment), and
leave it `true` for anything going to `main`.

**✅ Check:** run the pipeline once with `USE_DOCKER=false` — it should finish
in under a minute, no Docker stages shown. Run it again with the default —
you should see all 8 stages, ending in a live deployment.

---

## Phase 8 — Watch a canary deployment happen

After a successful build, watch it in the AWS Console under
**CodeDeploy > Applications > cartforge-app > Deployments**. You'll see:

- Traffic starts at 0% on the new (green) task set
- Jumps to 10%, holds for 5 minutes
- Jumps to 100% if nothing tripped the alarm
- Status flips to **Succeeded**

**✅ Check:** hit the ALB's DNS name in your browser partway through — you
have roughly a 1-in-10 chance of hitting the new version during the canary
window, and 100% after it completes.

---

## Phase 9 — Prove the rollback works

The whole point of automatic rollback is that you shouldn't have to think
about it during a real incident — so it's worth breaking things on purpose
once, safely, to see it happen:

1. Temporarily change the CartForge app to return an error on a route (or
   just break the Dockerfile so the container crash-loops)
2. Push it — the pipeline builds, scans, and deploys as canary
3. Error rate spikes → the CloudWatch alarm (`cartforge-5xx-alarm`) trips
4. CodeDeploy sees the alarm in `ALARM` state and automatically stops the
   deployment, shifting traffic back to the last-known-good task definition
5. Revert your intentional break, push again, confirm it deploys clean

**✅ Check:** during step 3–4, the ALB never serves the broken version to
100% of traffic — worst case is a few users see errors for the alarm's
evaluation window (2 minutes, per the sample alarm config) before it reverts.

---

## Phase 10 — Monitoring with Prometheus + Grafana

On a small separate EC2 (or the Jenkins box, if keeping this cheap):

```bash
scp -r -i key.pem monitoring ubuntu@<monitoring-ip>:~
ssh -i key.pem ubuntu@<monitoring-ip>
cd monitoring
docker compose up -d
```

This runs:
- **Prometheus** — scrapes metrics every 15s
- **Grafana** — dashboards (`http://<ip>:3000`, `admin` / `changeme` — change it)
- **cAdvisor + Node Exporter** — host/container metrics for the box it runs on
- **cloudwatch-exporter** — pulls ECS CPU/memory and ALB request/error/latency
  metrics from CloudWatch into a format Prometheus understands, so the same
  Grafana dashboards show your actual application health, not just the host

In Grafana: Connections > Data sources > Add Prometheus, URL
`http://prometheus:9090`. Then Dashboards > New > Import — search for
dashboard ID `1860` (Node Exporter Full) and `14282` (cAdvisor) to get
starter dashboards for free, and build one manual panel for
`aws_applicationelb_httpcode_target_5_xx_count_sum` so you can watch the
exact metric that drives your rollback alarm.

**✅ Check:** Grafana shows live CPU/memory graphs, and the 5xx panel spikes
during the Phase 9 test.

---

## Quick reference — file map

| File | Purpose |
|---|---|
| `Dockerfile` | Multi-stage build: Node builds the app, nginx serves it |
| `nginx.conf` | SPA routing fallback for the built React app |
| `Jenkinsfile` | The full pipeline: build → scan → push → deploy → rollback-on-failure |
| `security/.gitleaks.toml` | Gitleaks allowlist for known false positives |
| `security/.trivyignore` | Accepted CVEs (empty until you review something) |
| `ecs/taskdef.json` | ECS Fargate task definition template |
| `ecs/appspec.yaml` | CodeDeploy appspec template for ECS blue/green |
| `ecs/provision-reference-commands.sh` | One-time AWS resource setup (ECR/ECS/ALB/CodeDeploy/alarm) |
| `monitoring/docker-compose.yml` | Prometheus + Grafana + exporters |
| `monitoring/prometheus.yml` | Prometheus scrape targets |
| `monitoring/cloudwatch-exporter-config.yml` | Which CloudWatch metrics to expose to Prometheus |
| `scripts/setup-jenkins-ec2.sh` | Installs Jenkins, Docker, AWS CLI, Trivy, Gitleaks |
| `scripts/ssh-setup-notes.md` | `ssh-copy-id` steps for laptop→master and master→agent |

## Cost-saving tip

Everything here can be torn down and rebuilt in about 20 minutes once it's
scripted, so don't leave it running 24/7 as a portfolio piece:
`aws ecs update-service --desired-count 0 ...` and stop (don't necessarily
terminate) the EC2 instances between demos.
