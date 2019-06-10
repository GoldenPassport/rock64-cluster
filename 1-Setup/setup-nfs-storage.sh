#!/usr/bin/env bash

sudo mkdir -p /mnt/storage
sudo chown nobody:nogroup /mnt/storage
sudo chmod 777 /mnt/storage

sudo apt install nfs-kernel-server
sudo cp -a /etc/exports /etc/exports.backup
#sudo nano /etc/exports
#/mnt/storage/ 192.168.1.50(rw,sync,no_subtree_check,no_root_squash)
#/mnt/storage  192.168.1.0/24(rw,async,insecure,no_subtree_check,nohide)
printf "/mnt/storage/ 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)\n" >> /etc/exports

sudo exportfs -a
sudo systemctl restart nfs-kernel-server