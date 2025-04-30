#!/bin/bash

set -e

# -------------------------------
# Detect Hostname
# -------------------------------
HOSTNAME=$(hostname)
echo "[+] Detected hostname: $HOSTNAME"

# -------------------------------
# Define Paths and Variables
# -------------------------------
SMB_SERVER="10.19.0.15"
SMB_USER="mikebru10"
SMB_PASS="Catrina05#"
SMB_ROOT_SHARE="docker"
SMB_SHARE="//$SMB_SERVER/$SMB_ROOT_SHARE/$HOSTNAME"
MOUNT_POINT="/mnt/$HOSTNAME"
SMB_CREDENTIALS="$HOME/.smbcredentials"
FSTAB_FILE="/etc/fstab"
EXAMPLE_STACK_DIR="$MOUNT_POINT/compose-example"
EXAMPLE_VOLUME_DIR="$MOUNT_POINT/app-data/example-service"
EXAMPLE_COMPOSE_LOCAL="example-compose.yml"

# -------------------------------
# Require Root
# -------------------------------
if [[ $EUID -ne 0 ]]; then
    echo "Please run as root (sudo $0)"
    exit 1
fi

# -------------------------------
# Install Dependencies
# -------------------------------
echo "[+] Installing Docker, Docker Compose, CIFS and smbclient..."
apt-get update
apt-get install -y docker.io docker-compose cifs-utils smbclient

# Enable and start Docker
systemctl enable docker
systemctl start docker

# -------------------------------
# Create SMB Host Folder Remotely
# -------------------------------
echo "[+] Ensuring SMB folder exists for this host..."
smbclient "//$SMB_SERVER/$SMB_ROOT_SHARE" "$SMB_PASS" -U "$SMB_USER" -c "mkdir $HOSTNAME" || echo "[i] Folder may already exist."

# -------------------------------
# Write Credentials for Mount
# -------------------------------
echo "[+] Writing credentials to $SMB_CREDENTIALS..."
cat <<EOF > "$SMB_CREDENTIALS"
username=$SMB_USER
password=$SMB_PASS
EOF
chmod 600 "$SMB_CREDENTIALS"

# -------------------------------
# Create Mount Point
# -------------------------------
echo "[+] Creating mount point at $MOUNT_POINT..."
mkdir -p "$MOUNT_POINT"

# -------------------------------
# Add to /etc/fstab
# -------------------------------
FSTAB_ENTRY="//$SMB_SERVER/$SMB_ROOT_SHARE/$HOSTNAME $MOUNT_POINT cifs vers=3.0,credentials=$SMB_CREDENTIALS,iocharset=utf8,uid=1000,gid=1000,file_mode=0775,dir_mode=0775,nofail,x-systemd.automount 0 0"
if ! grep -qxF "$FSTAB_ENTRY" "$FSTAB_FILE"; then
    echo "$FSTAB_ENTRY" >> "$FSTAB_FILE"
    echo "[+] Added fstab entry for $HOSTNAME"
else
    echo "[i] fstab entry already exists"
fi

# -------------------------------
# Mount the NAS Share
# -------------------------------
echo "[+] Mounting NAS share..."
mount -a

# -------------------------------
# Create Folder Structure
# -------------------------------
echo "[+] Creating Docker directories..."
mkdir -p "$EXAMPLE_VOLUME_DIR"
mkdir -p "$EXAMPLE_STACK_DIR"

# -------------------------------
# Symlink for Convenience
# -------------------------------
ln -sf "$MOUNT_POINT/app-data" /srv/docker-volumes

# -------------------------------
# Copy Example Compose
# -------------------------------
if [[ -f "$EXAMPLE_COMPOSE_LOCAL" ]]; then
    echo "[+] Copying example-compose.yml to $EXAMPLE_STACK_DIR..."
    cp "$EXAMPLE_COMPOSE_LOCAL" "$EXAMPLE_STACK_DIR/docker-compose.yml"
else
    echo "[!] $EXAMPLE_COMPOSE_LOCAL not found. Skipping copy."
fi

# -------------------------------
# Done
# -------------------------------
echo "------------------------------------------------"
echo "[✓] Docker NAS setup complete for host: $HOSTNAME"
echo "[📂] Compose file: $EXAMPLE_STACK_DIR/docker-compose.yml"
echo "[📁] Volume dir: $EXAMPLE_VOLUME_DIR"
echo "[🧭] Run your stack:"
echo "     cd $EXAMPLE_STACK_DIR && docker-compose up -d"
echo "------------------------------------------------"
