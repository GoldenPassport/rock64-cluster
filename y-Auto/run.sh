#!/usr/bin/env bash

sudo bash teardown-run.sh
sleep 15s

sudo bash 1-run.sh
sleep 15s

sudo bash 2-run.sh
sleep 15s

sudo bash 3-run.sh
sleep 15s

sudo bash 4-run.sh

echo ""
echo "#####################################"
echo "### Enter below as a regular user ###"
echo "#####################################"
echo ""
echo "mkdir -p $HOME/.kube"
echo "sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config"
echo "sudo chown $(id -u):$(id -g) $HOME/.kube/config"

