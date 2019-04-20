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
apt update
apt upgrade

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
{ 
    apt-get purge -y kubelet
    echo "Successfully removed kubelet"
} || { 
    echo "kubelet not installed."
}

{ 
    apt-get purge -y kubeadm
    echo "Successfully removed kubeadm"
} || { 
    echo "kubeadm not installed."
}

{ 
    apt-get purge -y kubectl
    echo "Successfully removed kubectl"
} || { 
    echo "kubectl not installed."
}

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get install -y kubelet kubeadm kubectl
# apt-mark hold kubelet kubeadm kubectl

# Add User to Docker Group
usermod -aG docker $USER
usermod -aG docker rock

# Init Kubernetes
kubeadm config images pull
kubeadm init --pod-network-cidr=10.244.0.0/16

sleep 10s

#
# Post Install Setup
#

sysctl net.bridge.bridge-nf-call-iptables=1

# Install helm
if ! [ -x "$(command -v helm)" ]; then
  # echo 'Error: helm is not installed. It is required to deploy the Consul cluster.' >&2
  # exit 1
  curl https://raw.githubusercontent.com/helm/helm/master/scripts/get > get_helm.sh
  chmod 700 get_helm.sh
  ./get_helm.sh
fi

apt autoremove
