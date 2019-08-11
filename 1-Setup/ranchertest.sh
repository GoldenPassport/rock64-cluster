#!/usr/bin/env bash

if [ -z "${KUBECONFIG}" ]; then
    export KUBECONFIG=~/.kube/config
fi

# CAUTION - setting NAMESPACE will deploy most components to the given namespace
# however some are hardcoded to 'monitoring'. Only use if you have reviewed all manifests.

if [ -z "${NAMESPACE}" ]; then
    NAMESPACE=kube-system
fi

kctl() {
    kubectl --namespace "$NAMESPACE" "$@"
}

set -o xtrace

#
# Step 1 - Prepares system and installs: Docker, Kubernetes & Helm
#

sudo helm del --purge consul-traefik

kubectl drain rock1 --delete-local-data --force --ignore-daemonsets
kubectl delete node rock1
kubectl drain rock2 --delete-local-data --force --ignore-daemonsets
kubectl delete node rock2
kubectl drain rock2 --delete-local-data --force --ignore-daemonsets
kubectl delete node rock2
kubectl drain rock3 --delete-local-data --force --ignore-daemonsets
kubectl delete node rock3
kubectl drain rock4 --delete-local-data --force --ignore-daemonsets
kubectl delete node rock4

sudo kubeadm reset -f
sudo rm -rf $HOME/.kube
sudo rm -rf /var/lib/etcd

sleep 15s

#
# Step 2 - Prepare system and install: Docker, Kubernetes & Helm
#

# Update system
sudo apt update
sudo apt -y upgrade

# Reset ip tables
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X

# Disable swap
sudo swapoff -a 
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo systemctl disable armbian-zram-config.service

### Install packages to allow apt to use a repository over HTTPS
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

#
# Install Docker
#
sudo apt install -y docker.io
sudo apt-get install -y docker-compose 

## Set up the repository:

### Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

# Restart docker
sudo systemctl daemon-reload
sudo systemctl start docker
sudo systemctl enable docker
sudo systemctl restart docker

# Add user to docker group
sudo usermod -aG docker $USER
sudo usermod -aG docker rock

#
# Install Kubernetes
#

# Uninstall current packages
{ 
    sudo apt-get purge -y kubelet
    echo "Successfully removed kubelet"
} || { 
    echo "kubelet not installed."
}

{ 
    sudo apt-get purge -y kubeadm
    echo "Successfully removed kubeadm"
} || { 
    echo "kubeadm not installed."
}

{ 
    sudo apt-get purge -y kubectl
    echo "Successfully removed kubectl"
} || { 
    echo "kubectl not installed."
}

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"

sudo apt-get install -y kubelet kubeadm kubectl

# Init Kubernetes
kubeadm config images pull
kubeadm init --pod-network-cidr=10.244.0.0/16

sleep 10s

#
# Post Install Setup
#

sudo sysctl net.bridge.bridge-nf-call-iptables=1

# Install helm
if ! [ -x "$(command -v helm)" ]; then
  # echo 'Error: helm is not installed. It is required to deploy the Consul cluster.' >&2
  # exit 1
  curl https://raw.githubusercontent.com/helm/helm/master/scripts/get > get_helm.sh
  chmod 700 get_helm.sh
  ./get_helm.sh
fi

sudo apt -y autoremove
sleep 5s

mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl taint nodes --all node-role.kubernetes.io/master-
sleep 5s

#
# Step 3 - Install Flannel, MetalLB and (Kube) Dashboards
#

# Flannel
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/a70459be0084506e4ec919aa1c114638878db11b/Documentation/kube-flannel.yml
sleep 10s

# MetalLB
#kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml
#kubectl apply -f metallb.yaml


#
# Step 4 - Install storageClass and Traefik
#


#
# NFS-Storage
#

#sudo rm -rf /mnt/storage/*
#kubectl apply -f nfs-storage.yaml
##kubectl patch storageclass nfs-network -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
#kubectl patch deployment nfs-client-provisioner -n nfs-storage --patch '{"spec": {"template": {"spec": {"nodeSelector": {"beta.kubernetes.io/arch": "arm64"}}}}}'
#sleep 5s

#
# Tiller
#

kctl apply -f tiller.yaml
sleep 15s

sudo helm init --service-account tiller --tiller-image jessestuart/tiller
sleep 30s
# Patch Helm to land on an ARM node because of the used image
kubectl patch deployment tiller-deploy -n kube-system --patch '{"spec": {"template": {"spec": {"nodeSelector": {"beta.kubernetes.io/arch": "arm64"}}}}}'
sleep 15s

#kubectl apply -f traefik-external.yaml --namespace="kube-system"
#kctl apply -f metrics-server.yaml
#kubectl apply -f prometheus.yaml
#kubectl apply -f grafana.yaml

#
# Step 5 - Final instructions
#

helm install rancher-latest/rancher \
  --name rancher \
  --namespace cattle-system \
  --set hostname=rancher.goldenpassport.net \
  --set ingress.tls.source=letsEncrypt \
  --set letsEncrypt.email=support@goldenpassport.com
