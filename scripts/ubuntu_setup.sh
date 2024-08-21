#!/bin/bash
#
# ubuntu_setup.sh - Install all prerequisites on Ubuntu
# - tested with
#   . Windows 11 Pro WSL 2 Ubuntu
#   . Ubuntu Desktop (GNOME), Version 1.524OS Ubuntu 22.04
#     . https://marketplace.digitalocean.com/apps/ubuntu-desktop-gnome
#     . 2 vCPU / 4 GB RAM / regular SSD
#     . via ssh
#       . passwd user
#       . usermod -aG sudo user
#     . use RDP for GUI
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

# Run as a non-root user:
#   git clone https://github.com/muhme/joomla-branches-tester
#   cd joomla-branches-tester
#   sudo scripts/ubuntu_setup.sh
#   scripts/create.sh
#   scripts/test.sh

source scripts/helper.sh

# Running as sudo?
if [ "$(id -u)" -ne 0 ]; then
    error "This script must be run as root."
    exit 1
fi

# Make the hosts entry
log "Make hosts entry host.docker.internal"
echo "127.0.0.1 host.docker.internal" >> /etc/hosts

# Enable SMTP port in Ubuntu Uncomplicated Firewall (UFW)
log "Allow 7000:7999/tcp in Ubuntu Uncomplicated Firewall (UFW)"
sudo ufw allow 7000:7999/tcp

# Some basics with git
log "Install git and some base packages"
apt update
apt upgrade -y
apt install -y git vim iputils-ping net-tools telnet unzip

# Docker
log "Install Docker"
apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg > /etc/apt/trusted.gpg.d/docker.asc
add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update
apt install -y docker-ce

log "Adding '$USER' to the docker group"
usermod -aG docker $USER

log "Finished, make the necessary `sudo reboot`, after that try `docker ps`"
