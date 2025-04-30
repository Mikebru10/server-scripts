#!/bin/bash

set -e

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo."
  exit 1
fi

# --- Variables ---
EMAIL_RECIPIENT="mikebru10@protonmail.com"
REPO_URL="https://github.com/Mikebru10/server-scripts.git"
LOCAL_DIR="/home/mike/server-scripts"
SCRIPT_PATH="$(realpath "$0")"
HOSTNAME=$(hostname)
IP_ADDRESS=$(hostname -I | awk '{print $1}')
CRON_SCHEDULE="0 2 * * *"
TZ="America/Chicago"

# --- Functions ---

install_required_packages() {
  echo "Installing required packages (git, mailutils)..."
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -yq git mailutils
}

sync_repo() {
  echo "Syncing server-scripts from GitHub..."
  if [ -d "$LOCAL_DIR/.git" ]; then
    git -C "$LOCAL_DIR" reset --hard
    git -C "$LOCAL_DIR" pull origin main
  else
    echo "Cloning fresh copy to $LOCAL_DIR..."
    rm -rf "$LOCAL_DIR"
    git clone "$REPO_URL" "$LOCAL_DIR"
  fi
}

update_packages() {
  echo "Updating package lists..."
  apt-get update -y
  echo "Upgrading packages..."
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq
  echo "Performing full upgrade..."
  DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -yq
}

cleanup_system() {
  echo "Cleaning up..."
  apt-get autoremove -y
  apt-get autoclean -y
}

upgrade_release() {
  echo "Checking for release upgrades..."
  DEBIAN_FRONTEND=noninteractive apt-get install -yq update-manager-core
  if [ -f /etc/update-manager/release-upgrades ]; then
    echo "Upgrading to the latest release..."
    DEBIAN_FRONTEND=noninteractive do-release-upgrade -f DistUpgradeViewNonInteractive || echo "No release upgrade available or completed"
  fi
}

configure_auto_restart() {
  echo '* libraries/restart-without-asking boolean true' | debconf-set-selections
}

send_confirmation_email() {
  SUBJECT="Update/Upgrade for $HOSTNAME - $IP_ADDRESS has completed successfully"
  BODY="The update/upgrade process for '$HOSTNAME' ($IP_ADDRESS) completed successfully. Local scripts were synced from GitHub."
  echo "$BODY" | mailx -s "$SUBJECT" "$EMAIL_RECIPIENT"
}

setup_cronjob() {
  echo "Setting timezone to $TZ..."
  timedatectl set-timezone "$TZ"

  echo "Setting up cron job to run this script daily at 2:00 AM CST..."
  crontab -l 2>/dev/null | grep -F "$SCRIPT_PATH" > /dev/null
  if [ $? -ne 0 ]; then
    (crontab -l 2>/dev/null; echo "$CRON_SCHEDULE $SCRIPT_PATH") | crontab -
    echo "Cron job added."
  else
    echo "Cron job already exists."
  fi
}

# --- Main Execution ---
echo "Starting automated Ubuntu maintenance process..."

install_required_packages
sync_repo
update_packages
configure_auto_restart
upgrade_release
cleanup_system
send_confirmation_email
setup_cronjob

echo "All tasks complete. Rebooting now..."
reboot
