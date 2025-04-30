#!/bin/bash

set -e

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo."
  exit 1
fi

# Variables
EMAIL_RECIPIENT="mikebru10@protonmail.com"
REPO_URL="https://github.com/Mikebru10/server-scripts.git"
LOCAL_DIR="/home/mike/server-scripts"
HOSTNAME=$(hostname)
IP_ADDRESS=$(hostname -I | awk '{print $1}')
TEMP_DIR="/tmp/server-scripts-tmp"

# Clone or update the GitHub repo
sync_repo() {
  echo "Syncing server-scripts from GitHub..."

  # If the folder exists and is a Git repo, pull the latest changes
  if [ -d "$LOCAL_DIR/.git" ]; then
    echo "Existing repo found at $LOCAL_DIR. Pulling latest changes..."
    git -C "$LOCAL_DIR" reset --hard
    git -C "$LOCAL_DIR" pull origin main
  else
    echo "Repo not found locally. Cloning fresh copy to $LOCAL_DIR..."
    rm -rf "$LOCAL_DIR"
    git clone "$REPO_URL" "$LOCAL_DIR"
  fi
}

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
  BODY="The update/upgrade process for the server with hostname '$HOSTNAME' and IP address '$IP_ADDRESS' has completed successfully. Local scripts were also updated from GitHub."
  
  echo "$BODY" | mailx -s "$SUBJECT" "$EMAIL_RECIPIENT"
}

# MAIN EXECUTION
echo "Starting Ubuntu Server Update Script..."

sync_repo
update_packages
configure_auto_restart
upgrade_release
cleanup_system
send_confirmation_email

echo "Update complete. A confirmation email has been sent to $EMAIL_RECIPIENT."

echo "Rebooting the server..."
reboot
