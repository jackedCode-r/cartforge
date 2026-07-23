# SSH access setup - ssh-copy-id

You'll use `ssh-copy-id` in two places:

1. From your Laptop to the Jenkins Master EC2
2. From the Jenkins Master EC2 to the Jenkins Agent EC2
Note: This method is commonly used in training environments. Once the connection is working, you can later switch to passwordless SSH (ssh-copy-id), which is the recommended approach for Jenkins.
---

## 1. Laptop -> Jenkins master EC2
Step 1: Connect using the .pem key
ssh -i jenkins-master.pem ubuntu@<MASTER_PUBLIC_IP>
connect it 
---

## 2. Enable Password Authentication
**Jenkins node **, 

login in to the agent server 
Open the SSH configuration file:
sudo nano /etc/ssh/sshd_config
Make sure this setting exists:
PubkeyAuthentication yes
PasswordAuthentication yes
Also make sure this line is not disabled:
AuthorizedKeysFile .ssh/authorized_keys

save and exit and restart the server 
```bash
sudo systemctl restart ssh
```

# Set Password for Ubuntu User
```bash
sudo passwd ubuntu
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

if its still not work 
# trouble shoting 
root@ip-172-31-33-190:~# sudo sshd -T | grep passwordauthentication
passwordauthentication no

if its says now then its men that it is added somewhere 
then edit this file 
nano  /etc/ssh/sshd_config.d/60-cloudimg-settings.conf 
and make it yes 

and then restart your ssh and try again 
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
