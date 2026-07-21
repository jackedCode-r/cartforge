#!/usr/bin/env bash
# Run this on a fresh Ubuntu 22.04 EC2 instance (t3.medium or larger
# recommended) to set it up as the Jenkins server.
#
#   scp -i mykey.pem setup-jenkins-ec2.sh ubuntu@<EC2_IP>:~
#   ssh -i mykey.pem ubuntu@<EC2_IP>
#   chmod +x setup-jenkins-ec2.sh && ./setup-jenkins-ec2.sh
set -euo pipefail

echo ">>> Updating system packages"
sudo apt-get update -y && sudo apt-get upgrade -y

echo ">>> Installing Java (required by Jenkins)"
sudo apt-get install -y fontconfig openjdk-17-jre

echo ">>> Installing Jenkins"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
  sudo tee /etc/apt/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  "https://pkg.jenkins.io/debian-stable binary/" | \
  sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y jenkins
sudo systemctl enable --now jenkins

echo ">>> Installing Docker"
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo ">>> Letting Jenkins run docker commands"
sudo usermod -aG docker jenkins
sudo usermod -aG docker "$USER"
sudo systemctl restart jenkins

echo ">>> Installing AWS CLI v2"
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt-get install -y unzip
unzip -q awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws

echo ">>> Installing jq (used by the Jenkinsfile to edit task definitions)"
sudo apt-get install -y jq

echo ">>> Installing Trivy"
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | \
  sudo sh -s -- -b /usr/local/bin

echo ">>> Installing Gitleaks"
GITLEAKS_VERSION="8.18.4"
curl -sSL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
  -o gitleaks.tar.gz
sudo tar -xzf gitleaks.tar.gz -C /usr/local/bin gitleaks
rm gitleaks.tar.gz

echo ""
echo "=================================================================="
echo "Done. Jenkins initial admin password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
echo "Open http://<this-ec2-public-ip>:8080 to finish setup."
echo "=================================================================="
