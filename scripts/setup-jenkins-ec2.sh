#!/usr/bin/env bash

# Run this on a fresh Ubuntu EC2 instance.
# Recommended: t3.medium or larger
#
# Upload:
# scp -i mykey.pem setup-jenkins-ec2.sh ubuntu@<EC2_IP>:~
#
# Connect:
# ssh -i mykey.pem ubuntu@<EC2_IP>
#
# Run:
# chmod +x setup-jenkins-ec2.sh
# ./setup-jenkins-ec2.sh

set -euo pipefail

echo ">>> Updating system packages"
sudo apt-get update -y
sudo apt-get upgrade -y


# ============================================================
# INSTALL JAVA 21
# ============================================================

echo ">>> Installing Java 21"

sudo apt-get install -y \
  fontconfig \
  openjdk-21-jre

java -version


# ============================================================
# INSTALL JENKINS
# ============================================================

echo ">>> Installing Jenkins"

sudo mkdir -p /etc/apt/keyrings

# Remove any old Jenkins key if it exists
sudo rm -f /etc/apt/keyrings/jenkins-keyring.asc
sudo rm -f /usr/share/keyrings/jenkins-keyring.asc

# Install the CURRENT Jenkins 2026 repository signing key
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

# Add Jenkins LTS repository
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] \
https://pkg.jenkins.io/debian-stable binary/" | \
sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt-get update -y

sudo apt-get install -y jenkins

sudo systemctl enable jenkins
sudo systemctl start jenkins


# ============================================================
# INSTALL DOCKER
# ============================================================

echo ">>> Installing Docker"

sudo apt-get install -y \
  ca-certificates \
  curl \
  gnupg

sudo install -m 0755 -d /etc/apt/keyrings

# Remove old Docker key if present
sudo rm -f /etc/apt/keyrings/docker.gpg

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y

sudo apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin


# ============================================================
# ALLOW JENKINS TO USE DOCKER
# ============================================================

echo ">>> Allowing Jenkins to run Docker commands"

sudo usermod -aG docker jenkins
sudo usermod -aG docker "$USER"

sudo systemctl restart jenkins


# ============================================================
# INSTALL AWS CLI V2
# ============================================================

echo ">>> Installing AWS CLI v2"

sudo apt-get install -y unzip

curl -sSL \
  https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip \
  -o awscliv2.zip

unzip -q awscliv2.zip

sudo ./aws/install

rm -rf awscliv2.zip aws

aws --version


# ============================================================
# INSTALL JQ
# ============================================================

echo ">>> Installing jq"

sudo apt-get install -y jq


# ============================================================
# INSTALL TRIVY
# ============================================================

echo ">>> Installing Trivy"

curl -sfL \
  https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | \
  sudo sh -s -- -b /usr/local/bin

trivy --version


# ============================================================
# INSTALL GITLEAKS
# ============================================================

echo ">>> Installing Gitleaks"

GITLEAKS_VERSION="8.18.4"

curl -sSL \
  "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
  -o gitleaks.tar.gz

sudo tar -xzf gitleaks.tar.gz \
  -C /usr/local/bin gitleaks

rm -f gitleaks.tar.gz

gitleaks version


# ============================================================
# FINAL OUTPUT
# ============================================================

echo ""
echo "=================================================================="
echo " Jenkins installation completed successfully!"
echo "=================================================================="

echo ""
echo "Jenkins Status:"
sudo systemctl status jenkins --no-pager

echo ""
echo "Jenkins Initial Admin Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

echo ""
echo "Open Jenkins in your browser:"
echo "http://<EC2-PUBLIC-IP>:8080"

echo ""
echo "Make sure your EC2 Security Group allows:"
echo "TCP 8080 from your IP address"
echo "=================================================================="
