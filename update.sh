#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo."
  exit 1
fi

# Load email recipient from environment variable
EMAIL_RECIPIENT="${EMAIL_RECIPIENT:-default@example.com}"

# Get hostname and IP address
HOSTNAME=$(hostname)
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Function to update and upgrade packages
update_packages() {
  echo "Updating package lists..."
  apt-get update -y

  echo "Upgrading packages..."
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq

  echo "Performing full upgrade..."
  DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -yq
}

# Function to remove unused packages
cleanup_system() {
  echo "Removing unused packages..."
  apt-get autoremove -y
  apt-get autoclean -y
}

# Function to upgrade the release
upgrade_release() {
  echo "Checking for release upgrades..."
  apt-get install -yq update-manager-core

  if [ -f /etc/update-manager/release-upgrades ]; then
    echo "Upgrading to the latest release..."
    DEBIAN_FRONTEND=noninteractive do-release-upgrade -f DistUpgradeViewNonInteractive
  else
    echo "Release upgrades not available."
  fi
}

# Function to restart services automatically
configure_auto_restart() {
  echo "Configuring automatic service restarts during upgrades..."
  echo '* libraries/restart-without-asking boolean true' | debconf-set-selections
}

# Function to send a confirmation email
send_confirmation_email() {
  SUBJECT="Update/Upgrade for $HOSTNAME - $IP_ADDRESS has completed successfully"
  BODY="The update/upgrade process for the server with hostname '$HOSTNAME' and IP address '$IP_ADDRESS' has completed successfully."
  
  echo "$BODY" | mailx -s "$SUBJECT" "$EMAIL_RECIPIENT"
}

# Main script execution
echo "Starting Ubuntu Server Update Script..."

# Update and upgrade the system
update_packages

# Configure automatic service restarts
configure_auto_restart

# Upgrade the Ubuntu release
upgrade_release

# Clean up the system
cleanup_system

# Send confirmation email
send_confirmation_email

echo "Update complete. A confirmation email has been sent to $EMAIL_RECIPIENT."

# Reboot the server
echo "Rebooting the server..."
reboot
