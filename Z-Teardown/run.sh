#!/bin/bash

kubectl drain rock1 --delete-local-data --force --ignore-daemonsets
kubectl delete node rock1
kubectl drain rock2 --delete-local-data --force --ignore-daemonsets
kubectl delete node rock2
kubectl drain rock3 --delete-local-data --force --ignore-daemonsets
kubectl delete node rock3
kubectl drain rock4 --delete-local-data --force --ignore-daemonsets
kubectl delete node rock4

sudo root
kubeadm reset -f
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
