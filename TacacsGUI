#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run this script as root or using sudo."
  exit 1
fi

# Update and upgrade the system
apt update && apt upgrade -y

# Install required packages
apt install -y git cifs-utils curl wget

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Install Cloudmin
wget http://cloudmin.virtualmin.com/gpl/scripts/cloudmin-kvm-debian-install.sh
chmod +x cloudmin-kvm-debian-install.sh
./cloudmin-kvm-debian-install.sh

# Install TacacsGUI
cd ~
rm -rf tgui_install*
wget https://github.com/tacacsgui/tgui_install/releases/download/2.0.2/tgui_install.tar.gz
mkdir tgui_install
tar -xvf tgui_install.tar.gz -C tgui_install --strip-components 1
cd tgui_install
chmod 755 tacacsgui.sh
./tacacsgui.sh silent

# Clean up
cd ~
rm -rf tgui_install tgui_install.tar.gz cloudmin-kvm-debian-install.sh

echo "Installation completed successfully."
