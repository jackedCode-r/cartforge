# SSH access setup - ssh-copy-id

You'll use `ssh-copy-id` in two places:

1. From your **laptop** to the **Jenkins master EC2** (connect it using the .pem key )

---

## 1. Laptop -> Jenkins master EC2
connect it 
---

## 2. Jenkins master EC2 -> Jenkins agent EC2
Launch a second, smaller EC2 instance to act as the build agent (keeps heavy
`npm ci` / `docker build` / `trivy scan` work off the master). On the
**Jenkins master**, generate a dedicated key pair just for talking to agents:

login in to the agent server 
Open the SSH configuration file:
sudo nano /etc/ssh/sshd_config
Make sure this setting exists:
PubkeyAuthentication yes
Also make sure this line is not disabled:
AuthorizedKeysFile .ssh/authorized_keys

save and exit and restart the server 
```bash
sudo systemctl restart ssh
```
on the master server 
```bash
ssh-keygen 
sudo -u jenkins ssh-copy-id \ -i /var/lib/jenkins/.ssh/id_ed25519.pub \ ubuntu@<AGENT_PRIVATE_IP>

example
sudo -u jenkins ssh-copy-id \ -i /var/lib/jenkins/.ssh/id_ed25519.pub \ ubuntu@10.0.2.25
```
type yes and go on 


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
