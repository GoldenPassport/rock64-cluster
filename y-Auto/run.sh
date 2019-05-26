#!/usr/bin/env bash

echo "####################################"
echo "### Requires sudo                ###"
echo "####################################"

sudo bash teardown-run.sh
sleep 30s

sudo bash 1-run.sh
sleep 30s

sudo bash 2-run.sh
sleep 30s

sudo bash 3-run.sh
sleep 30s

echo "mkdir -p $HOME/.kube"
echo "sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config"
echo "sudo chown $(id -u):$(id -g) $HOME/.kube/config"
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
