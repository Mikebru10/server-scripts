#!/bin/bash
# PXE Boot Server Health Check Script for Raspberry Pi Cluster
# Checks for required services, storage, partitions, and sync status

LOGFILE="/var/log/pxe_status.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== PXE Health Check Started at $(date) ==="

# Detect the role based on IP address
IP_ADDR=$(hostname -I | awk '{print $1}')
PRIMARY_IP="10.19.1.11"
SECONDARY_IP="10.19.1.12"

if [[ "$IP_ADDR" == "$PRIMARY_IP" ]]; then
    ROLE="primary"
    OTHER_HOST="$SECONDARY_IP"
elif [[ "$IP_ADDR" == "$SECONDARY_IP" ]]; then
    ROLE="secondary"
    OTHER_HOST="$PRIMARY_IP"
else
    echo "[ERROR] Unrecognized IP ($IP_ADDR). This script must run on $PRIMARY_IP or $SECONDARY_IP."
    exit 1
fi

echo "Running as $ROLE node (IP: $IP_ADDR), checking against $OTHER_HOST"

# Function to check service status
check_service() {
    if systemctl is-active --quiet "$1"; then
        echo "[OK] Service $1 is running."
    else
        echo "[ERROR] Service $1 is NOT running!"
    fi
}

# Function to compare file lists between local and remote host
compare_files() {
    LOCAL_LIST=$(find /srv/tftpboot -type f | sort | md5sum)
    REMOTE_LIST=$(ssh "$OTHER_HOST" "find /srv/tftpboot -type f | sort | md5sum" 2>/dev/null)

    if [[ "$LOCAL_LIST" == "$REMOTE_LIST" ]]; then
        echo "[OK] PXE directories are in sync."
    else
        echo "[WARNING] PXE directories on $IP_ADDR and $OTHER_HOST are NOT in sync!"
    fi
}

# Function to check disk partitions
check_partitions() {
    echo "Disk Partitions and Usage:"
    lsblk -o NAME,FSTYPE,MOUNTPOINT,SIZE | grep -v "loop"
}

# Check if the other host is reachable
if ping -c 1 "$OTHER_HOST" &>/dev/null; then
    echo "[OK] Network connectivity with $OTHER_HOST is active."
else
    echo "[ERROR] Cannot reach $OTHER_HOST. Check network connectivity!"
fi

# Check services on the current host
echo "Checking required services on $IP_ADDR..."
check_service "tftpd-hpa"
check_service "vsftpd"
check_service "smbd"
check_service "nfs-kernel-server"
check_service "docker"

# Only check HAProxy on the primary
if [[ "$ROLE" == "primary" ]]; then
    check_service "haproxy"
fi

# Check if the PXE boot directory exists
if [[ -d "/srv/tftpboot" ]]; then
    echo "[OK] PXE boot directory exists at /srv/tftpboot."
else
    echo "[ERROR] PXE boot directory /srv/tftpboot is missing!"
fi

# Compare file lists with the other host
if ssh "$OTHER_HOST" "ls /srv/tftpboot" &>/dev/null; then
    compare_files
else
    echo "[WARNING] Unable to check file sync with $OTHER_HOST (SSH access may be missing)."
fi

# Check Rsync status (only on primary)
if [[ "$ROLE" == "primary" ]]; then
    if crontab -l | grep -q "pxe_sync.sh"; then
        echo "[OK] Rsync cron job is set up for synchronization."
    else
        echo "[ERROR] Rsync cron job is missing!"
    fi
fi

# Check partition details
echo "Checking partition and disk usage on $IP_ADDR..."
check_partitions

# If reachable, check the other host's partitions
if ssh "$OTHER_HOST" "lsblk" &>/dev/null; then
    echo "Checking partition and disk usage on $OTHER_HOST..."
    ssh "$OTHER_HOST" "$(declare -f check_partitions); check_partitions"
else
    echo "[WARNING] Unable to retrieve partition info from $OTHER_HOST."
fi

# Summary
echo "=== PXE Health Check Completed at $(date) ==="
