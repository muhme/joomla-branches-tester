#!/bin/bash
#
# ubuntu_setup.sh - Install all prerequisites on Ubuntu.
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

function help {
    echo "*** ubuntu_setup.sh – Install all prerequisites on Ubuntu."
}

while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  else
    help
    echo "*** Error: Argument '$1' is not valid."
    exit 1
  fi
done

# Running as sudo?
if [ "$(id -u)" -ne 0 ]; then
    echo "*** Error: Please run this script as root user with sudo."
    exit 1
fi

# Make the hosts entry
HOSTS_FILE="/etc/hosts"
if grep -q host.docker.internal "${HOSTS_FILE}"; then
  echo "*** Entry 'host.docker.internal' exists already in '${HOSTS_FILE}' file."
else
  echo "*** Adding entry '127.0.0.1 host.docker.internal' to the file '${HOSTS_FILE}'."
  echo "127.0.0.1 host.docker.internal" >> "${HOSTS_FILE}"
fi

# Enable SMTP port in Ubuntu Uncomplicated Firewall (UFW)
echo "*** Allow port range 7000:7999/tcp in Ubuntu Uncomplicated Firewall (UFW)."
# This is possible even UFW is disabled or the rules exist already
ufw allow 7000:7999/tcp

# Some basics with git
echo "*** Installing git and some base packages."
# This can run multiple times
apt-get update
apt-get upgrade -y
apt-get install -y git vim iputils-ping net-tools telnet unzip

# Docker
echo "*** Installing Docker."
# This can run multiple times
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg > /etc/apt/trusted.gpg.d/docker.asc
add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce

echo "*** Adding '$USER' user to the docker group."
# This can run multiple times
usermod -aG docker $USER

echo "*** Finished. Please run 'sudo reboot', and after that, try 'docker ps'."
