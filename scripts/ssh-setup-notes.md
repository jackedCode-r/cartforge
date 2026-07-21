# SSH access setup - ssh-copy-id

You'll use `ssh-copy-id` in two places:

1. From your **laptop** to the **Jenkins master EC2** (so you can manage it
   without typing a password / re-specifying the .pem file every time).
2. From the **Jenkins master EC2** to the **Jenkins agent EC2** (so Jenkins
   can launch build agents over SSH - this is how the "Jenkins agent"
   requirement is implemented).

---

## 1. Laptop -> Jenkins master EC2

EC2 already gave you a `.pem` key pair when you launched the instance. To
also enable plain `ssh ubuntu@<ip>` (no `-i key.pem` needed) and let
`ssh-copy-id` work at all, first generate a personal key pair if you don't
have one:

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
# press enter through the prompts (default path ~/.ssh/id_ed25519)
```

Copy it to the Jenkins EC2 instance (you still need the .pem for this first
connection, since your key isn't authorized yet):

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub -o "ProxyCommand=none" \
  -o IdentityFile=~/path/to/aws-key.pem ubuntu@<JENKINS_EC2_PUBLIC_IP>
```

If your local `ssh-copy-id` doesn't support mixing identity files that
way, just do it manually instead:

```bash
cat ~/.ssh/id_ed25519.pub | ssh -i ~/path/to/aws-key.pem ubuntu@<JENKINS_EC2_PUBLIC_IP> \
  "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
```

Test it:
```bash
ssh ubuntu@<JENKINS_EC2_PUBLIC_IP>   # should log in with no password/key flag
```

---

## 2. Jenkins master EC2 -> Jenkins agent EC2

Launch a second, smaller EC2 instance to act as the build agent (keeps heavy
`npm ci` / `docker build` / `trivy scan` work off the master). On the
**Jenkins master**, generate a dedicated key pair just for talking to agents:

```bash
sudo -u jenkins ssh-keygen -t ed25519 -f /var/lib/jenkins/.ssh/id_ed25519 -N ""
```

Copy the public key to the agent instance:

```bash
sudo -u jenkins ssh-copy-id -i /var/lib/jenkins/.ssh/id_ed25519.pub \
  -o IdentityFile=~/path/to/aws-key.pem ubuntu@<AGENT_EC2_PRIVATE_IP>
```

(Use the agent's private IP if master and agent are in the same VPC - keeps
traffic off the public internet.)

Test from the Jenkins user:
```bash
sudo -u jenkins ssh ubuntu@<AGENT_EC2_PRIVATE_IP> "echo connected"
```

---

## 3. Register the agent in Jenkins

1. Manage Jenkins > Nodes > New Node
2. Name it `cartforge-agent`, type **Permanent Agent**
3. Remote root directory: `/home/ubuntu/jenkins-agent`
4. Launch method: **Launch agents via SSH**
   - Host: agent's private IP
   - Credentials: add a new "SSH Username with private key" credential,
     paste the contents of `/var/lib/jenkins/.ssh/id_ed25519` (private key)
     as the Jenkins master generated above
   - Host Key Verification Strategy: "Non verifying" (fine for a learning
     project; use "Known hosts file" for anything production-grade)
5. Save, then check **Manage Jenkins > Nodes** - it should show as connected.

In your `Jenkinsfile`, you can then pin stages to that agent with
`agent { label 'cartforge-agent' }` instead of `agent any`, once it's set up.
