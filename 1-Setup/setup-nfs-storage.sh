#!/usr/bin/env bash

# List devices
# fdisk -l
# Get UUIDs
# blkid
# mkdir /mnt/storage
# Update fstab
# echo "UUID=70b88bba-f5b4-4c62-af60-da6a2a38ea81 /mnt/storage ext4 defaults,noatime,nodiratime,commit=600,errors=remount-ro 0 1" >>  /etc/fstab 
# sudo mount -a

if grep -qs "/mnt/storage" /etc/exports; then
    sudo umount /mnt/storage
    sudo rm -rf /mnt/storage
else
    sudo cp -a /etc/exports /etc/exports.backup
    printf "/mnt/storage/ 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)\n" >> /etc/exports
fi

sudo mkdir -p /mnt/storage
sudo chown nobody:nogroup /mnt/storage
sudo chmod 777 /mnt/storage

sudo apt install nfs-kernel-server
sudo exportfs -a
sudo systemctl restart nfs-kernel-server