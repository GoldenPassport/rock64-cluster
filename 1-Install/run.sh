#!/bin/bash

echo "####################################"
echo "### Need to be logged in as root ###"
echo "####################################"

echo "Container Linux installation script"
echo "This will install:"
echo " - Docker Community Edition"
echo " - Docker Compose"
echo " - Kubernetes: kubeadm, kubelet and kubectl"
echo ""

set -xeo pipefail

# Update
apt update && apt upgrade

# Reset ip tables
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X

# Disable swap
sudo swapoff -a 
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
systemctl disable armbian-zram-config.service

#
# Install Docker CE
#

## Set up the repository:
### Install packages to allow apt to use a repository over HTTPS
apt-get update && apt-get install apt-transport-https ca-certificates curl software-properties-common

### Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

### Add Docker apt repository.
sudo add-apt-repository \
   "deb [arch=arm64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

## Install Docker CE.
apt-get install -y docker-ce docker-compose 

# Setup daemon.
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

# Restart docker.
systemctl daemon-reload
systemctl restart docker

#
# Install Kubernetes
#

# Uninstall current packages
if apt-get -qq install kubelet; then
    apt-get purge kubelet
    echo "Successfully removed kubelet"
else
    echo "kubelet not installed."
fi

if apt-get -qq install kubeadm; then
    apt-get purge kubeadm
    echo "Successfully removed kubeadm"
else
    echo "kubeadm not installed."
fi

if apt-get -qq install kubectl; then
    apt-get purge kubectl
    echo "Successfully removed kubectl"
else
    echo "kubectl not installed."
fi

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get install -y --allow-change-held-packages kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Add User to Docker Group
usermod -aG docker $USER
usermod -aG docker rock

# Init Kubernetes
kubeadm config images pull
kubeadm init --pod-network-cidr=10.244.0.0/16

#
# Post Install Setup
#

sysctl net.bridge.bridge-nf-call-iptables=1
