#!/bin/bash

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl drain rock1 --delete-local-data --force --ignore-daemonsets
kubectl delete node rock1
kubectl drain rock2 --delete-local-data --force --ignore-daemonsets
kubectl delete node rock2
kubectl drain rock3 --delete-local-data --force --ignore-daemonsets
kubectl delete node rock3
kubectl drain rock4 --delete-local-data --force --ignore-daemonsets
kubectl delete node rock4

echo "### Enter root password ###"
su root
kubeadm reset -f
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
