#!/bin/bash
#
# ubuntu_setup.sh - install all prerequisites on Ubuntu
# - tested with
#   . Ubuntu Desktop (GNOME), Version 1.524OS Ubuntu 22.04
#   . https://marketplace.digitalocean.com/apps/ubuntu-desktop-gnome
#   . 4 vCPU / 8 GB RAM / regular SSD
#
# MIT License, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-system-tests

# if you wish to replace the default random created passwords:
#   root# x11vnc -storepasswd yourPassword /home/user/.vnc/passwd
#   root# passwd user

# run as a user execute:
#   git clone https://github.com/muhme/joomla-system-tests
#   cd joomla-system-tests
#   sudo scripts/ubuntu_setup.sh
#   scripts/create.sh
#   scripts/test.sh

# prerequisites
echo "127.0.0.1 host.docker.internal" >> /etc/hosts
ufw allow 7025

# git and some basics
apt update
sudo apt install -y git vim iputils-ping net-tools telnet

# docker
apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg > /etc/apt/trusted.gpg.d/docker.asc
add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update
apt install -y docker-ce
usermod -aG docker $USER
