#!/bin/bash

# === CONFIG ===
EMAIL_PLACEHOLDER="default@example.com"
COMMIT_MESSAGE="Add auto-update workflow and update script"

# === FILE PATHS ===
SCRIPT_DIR="$(pwd)"
UPDATE_SCRIPT="$SCRIPT_DIR/update.sh"
WORKFLOW_FILE="$SCRIPT_DIR/.github/workflows/update.yml"

# === Create directory if needed ===
mkdir -p "$(dirname "$WORKFLOW_FILE")"

# === Write update.sh ===
cat << EOF > "$UPDATE_SCRIPT"
#!/bin/bash

# Ensure the script is run as root
if [ "\$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo."
  exit 1
fi

# Load email from environment
EMAIL_RECIPIENT="\${EMAIL_RECIPIENT:-$EMAIL_PLACEHOLDER}"

# Get hostname and IP
HOSTNAME=\$(hostname)
IP_ADDRESS=\$(hostname -I | awk '{print \$1}')

update_packages() {
  echo "Updating package lists..."
  apt-get update -y
  echo "Upgrading packages..."
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq
  echo "Performing full upgrade..."
  DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -yq
}

cleanup_system() {
  echo "Cleaning up unused packages..."
  apt-get autoremove -y
  apt-get autoclean -y
}

upgrade_release() {
  echo "Checking for release upgrades..."
  apt-get install -yq update-manager-core
  if [ -f /etc/update-manager/release-upgrades ]; then
    echo "Upgrading OS..."
    DEBIAN_FRONTEND=noninteractive do-release-upgrade -f DistUpgradeViewNonInteractive
  else
    echo "Release upgrades not available."
  fi
}

configure_auto_restart() {
  echo '* libraries/restart-without-asking boolean true' | debconf-set-selections
}

send_confirmation_email() {
  SUBJECT="[\$HOSTNAME] Update complete - \$IP_ADDRESS"
  BODY="Server \$HOSTNAME (\$IP_ADDRESS) completed the update/upgrade successfully."
  echo "\$BODY" | mailx -s "\$SUBJECT" "\$EMAIL_RECIPIENT"
}

# Main routine
echo "Starting system update on \$HOSTNAME (\$IP_ADDRESS)..."
update_packages
configure_auto_restart
upgrade_release
cleanup_system
send_confirmation_email
echo "Rebooting..."
reboot
EOF

# === Write GitHub Actions Workflow ===
cat << 'EOF' > "$WORKFLOW_FILE"
name: System Update

on:
  workflow_dispatch:
  schedule:
    - cron: '0 3 * * *'

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Set up email environment variable
        run: echo "EMAIL_RECIPIENT=${{ secrets.EMAIL_RECIPIENT }}" >> $GITHUB_ENV

      - name: Make script executable
        run: chmod +x update.sh

      - name: Run update script
        run: ./update.sh
EOF

# === Set executable permission ===
chmod +x "$UPDATE_SCRIPT"

# === Git Add, Commit & Push ===
git add "$UPDATE_SCRIPT" "$WORKFLOW_FILE"
git commit -m "$COMMIT_MESSAGE"
git push

echo "✅ Auto-update feature has been committed and pushed."
echo "📌 Be sure to add the secret 'EMAIL_RECIPIENT' in your GitHub repository settings."
