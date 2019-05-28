#!/bin/bash

# Reset if needed
sudo kubeadm reset -f

# Install docker
sudo apt-get install -y aufs-tools debootstrap rinse zfsutils-linux nfs-kernel-server cgroupfs-mount
sudo apt install -y docker.io
sudo apt-get install -y docker-compose docker-doc 

# Restart docker
systemctl daemon-reload
systemctl start docker
systemctl enable docker
systemctl restart docker

# Add user to docker group
usermod -aG docker $USER
usermod -aG docker rock

# Install kubernetes
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

sudo printf "net.ipv6.conf.all.disable_ipv6 = 1\nnet.ipv6.conf.default.disable_ipv6 = 1\nnet.ipv6.conf.lo.disable_ipv6 = 1\nnet.ipv6.conf.eth0.disable_ipv6 = 1" >> /etc/sysctl.conf

cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl

sudo apt -y upgrade
sudo apt -y autoremove
