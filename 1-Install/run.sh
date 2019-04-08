#!/bin/bash
echo "Container Linux installation script"
echo "This will install:"
echo " - Docker Community Edition"
echo " - Docker Compose"
echo " - Kubernetes: kubeadm, kubelet and kubectl"
echo ""

set -xeo pipefail

#
# A. Install Docker CE
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
apt-get update && apt-get install docker-ce docker-compose 

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
# B. Install Kubernetes
#

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Add User to Docker Group
usermod -aG docker $USER

# Init Kubernetes
kubeadm config images pull
kubeadm init --pod-network-cidr=10.244.0.0/16

sleep 5s

kubectl taint nodes --all node-role.kubernetes.io/master-

#
# C. Post Install Setup
#

sysctl net.bridge.bridge-nf-call-iptables=1

su rock
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Flannel
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/a70459be0084506e4ec919aa1c114638878db11b/Documentation/kube-flannel.yml
