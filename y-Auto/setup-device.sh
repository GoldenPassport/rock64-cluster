#!/bin/bash

if [[ $# -eq 0 ]] ; then
    echo "Run the script with the required details - e.g.: bash setup-device.sh [static ip address] [hostname]"
    exit 0
fi

# Update base system
sudo apt -y update
sudo apt -y upgrade

# Update packages
sudo apt-get -y update
sudo apt-get -y upgrade

sudo apt -y autoremove

# Disable NetworkManager

sudo systemctl stop NetworkManager
sudo systemctl disable NetworkManager
sudo systemctl daemon-reload

# Configure network
sudo printf "allow-hotplug eth0\nauto eth0\niface eth0 inet static\n  address ${1}\n  netmask 255.255.255.0\n  gateway 192.168.1.1\n  dns-nameservers 192.168.1.1" > /etc/network/interfaces.d/eth0

# Disable IPv6
sudo printf "net.ipv6.conf.all.disable_ipv6 = 1\nnet.ipv6.conf.default.disable_ipv6 = 1\nnet.ipv6.conf.lo.disable_ipv6 = 1\nnet.ipv6.conf.eth0.disable_ipv6 = 1" >> /etc/sysctl.conf

# Set DNS
sudo rm /etc/resolv.conf
sudo touch /etc/resolv.conf
sudo printf "nameserver 192.168.1.1" > /etc/resolv.conf

# Change hostname
sudo printf "${1}  ${2}" >> /etc/hosts
sudo printf "${2}" > /etc/hostname
sudo hostname ${2}

sudo service networking restart

# Disable Swap

sudo swapoff -a 
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
systemctl disable armbian-zram-config.service

# Add User to Sudoers
#sudo printf "rock ALL=(ALL) NOPASSWD:ALL" >> visudo

# Create SSH Keys
ssh-keygen -t rsa

echo "#####################################"
echo "### COMPLETED! PLEASE REBOOT      ###"
echo "#####################################"