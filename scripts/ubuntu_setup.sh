#!/bin/bash
#
# ubuntu_setup.sh - Install all prerequisites on Ubuntu
# - tested with
#   . Windows 11 Pro WSL 2
#   . Ubuntu Desktop (GNOME), Version 1.524OS Ubuntu 22.04
#     . https://marketplace.digitalocean.com/apps/ubuntu-desktop-gnome
#     . 4 vCPU / 8 GB RAM / regular SSD
#
# MIT License, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

# if you wish to replace the default random created passwords:
#   root# x11vnc -storepasswd yourPassword /home/user/.vnc/passwd
#   root# passwd user

# Run as a non-root user:
#   git clone https://github.com/muhme/joomla-branches-tester
#   cd joomla-branches-tester
#   sudo scripts/ubuntu_setup.sh
#   scripts/create.sh
#   scripts/test.sh

# Running as sudo?
if [ "$(id -u)" -ne 0 ]; then
    echo "*** This script must be run as root. Exiting."
    exit 1
fi

# prerequisites
echo "127.0.0.1 host.docker.internal" >> /etc/hosts
ufw allow 7025

# git and some basics
apt update
apt install -y git vim iputils-ping net-tools telnet

# Docker
apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg > /etc/apt/trusted.gpg.d/docker.asc
add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update
apt install -y docker-ce

echo "*** Adding '$USER' to the docker group"
usermod -aG docker $USER

echo "*** Make the necessary `sudo reboot`, after that try `docker ps`"
