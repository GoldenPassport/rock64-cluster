#!/bin/bash

# Install docker
sudo apt-get install -y aufs-tools debootstrap docker-doc rinse zfsutils-linux nfs-kernel-server cgroupfs-mount
sudo apt install -y docker.io
sudo apt-get install -y docker-compose

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

cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

sudo apt-get install -y kubelet kubeadm kubectl