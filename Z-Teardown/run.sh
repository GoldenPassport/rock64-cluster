#!/bin/bash

echo "### Need to be logged in as root"

su - rock -c "mkdir -p $HOME/.kube"
su - rock -c "sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config"
su - rock -c "sudo chown $(id -u):$(id -g) $HOME/.kube/config"

su - rock -c "kubectl drain rock1 --delete-local-data --force --ignore-daemonsets"
su - rock -c "kubectl delete node rock1"
su - rock -c "kubectl drain rock2 --delete-local-data --force --ignore-daemonsets"
su - rock -c "kubectl delete node rock2"
su - rock -c "kubectl drain rock3 --delete-local-data --force --ignore-daemonsets"
su - rock -c "kubectl delete node rock3"
su - rock -c "kubectl drain rock4 --delete-local-data --force --ignore-daemonsets"
su - rock -c "kubectl delete node rock4"

kubeadm reset -f
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
