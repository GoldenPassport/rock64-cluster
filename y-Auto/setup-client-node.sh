#!/bin/bash

# Install docker
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

sudo apt-get install -y kubelet kubeadm kubectl