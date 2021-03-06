#!/usr/bin/env bash

set -o xtrace

#
# Step 1 - Remove previous installations
#

# Uninstall current packages
docker rm -f $(docker ps -qa)
docker volume rm $(docker volume ls -q)
cleanupdirs="/var/lib/etcd /etc/kubernetes /etc/cni /opt/cni /var/lib/cni /var/run/calico /opt/rke"
for dir in $cleanupdirs; do
  echo "Removing $dir"
  rm -rf $dir
done

# Reset ip tables
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X

#
# Step 2 - Prepare system and install: Docker, Kubernetes & Helm
#

# Update system
apt update
apt -y upgrade

# Disable swap
swapoff -a 
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
systemctl disable armbian-zram-config.service

### Install packages to allow apt to use a repository over HTTPS
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common

#
# Install Docker
#

### Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
apt install -y docker.io
apt-get install -y docker-compose 

# Restart docker
systemctl daemon-reload
systemctl start docker
systemctl enable docker
systemctl restart docker

# Add user to docker group
usermod -aG docker $USER
usermod -aG docker rock