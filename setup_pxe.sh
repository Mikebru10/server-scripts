#!/bin/bash
# PXE Boot Server Setup Script for Raspberry Pi 4 (Primary or Secondary)

LOG="/var/log/pxe_setup.log"
exec >>"$LOG" 2>&1   # Log all output to file

echo "=== PXE Setup Script Started at $(date) ==="

# 1. Determine if this is Primary or Secondary based on IP
ROLE=""
IP_ADDR=$(hostname -I || echo "0.0.0.0")
if [[ "$IP_ADDR" == *"10.19.1.11"* ]]; then
    ROLE="primary"
elif [[ "$IP_ADDR" == *"10.19.1.12"* ]]; then
    ROLE="secondary"
else
    echo "[ERROR] Unrecognized IP ($IP_ADDR). This script must run on 10.19.1.11 or 10.19.1.12."
    exit 1
fi
echo "Running as $ROLE node (IP: $IP_ADDR)"

# 2. Install required packages for PXE services and other tools
echo "Updating package list..."
apt-get update -y || { echo "[ERROR] apt-get update failed"; exit 1; }
# List of packages: TFTP server, FTP server, Samba, NFS server, rsync, (optional: docker.io, docker-compose if available)
PKG_LIST="tftpd-hpa vsftpd samba nfs-kernel-server rsync"
# Include Docker packages if available in apt (for Raspbian, docker.io may be old; script will handle docker separately if not)
PKG_LIST+=" docker.io docker-compose"
echo "Installing packages: $PKG_LIST"
DEBIAN_FRONTEND=noninteractive apt-get install -y $PKG_LIST || { echo "[ERROR] Package installation failed"; exit 1; }

# 3. Configure TFTP (tftpd-hpa)
TFTP_DIR="/srv/tftpboot"
echo "Configuring TFTP server (tftpd-hpa)..."
if grep -q '^TFTP_DIRECTORY=' /etc/default/tftpd-hpa; then
    sed -i 's#^TFTP_DIRECTORY=.*#TFTP_DIRECTORY="'"$TFTP_DIR"'"#' /etc/default/tftpd-hpa
else
    # Add config if not present
    cat <<EOF >> /etc/default/tftpd-hpa
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="$TFTP_DIR"
TFTP_ADDRESS="0.0.0.0:69"
TFTP_OPTIONS="--secure --create"
EOF
fi
mkdir -p "$TFTP_DIR"
chown tftp:tftp "$TFTP_DIR"

# 4. Configure NFS export
echo "Configuring NFS server..."
NFSEXPORT="$TFTP_DIR *(rw,sync,no_subtree_check,no_root_squash)"
if ! grep -qx "$NFSEXPORT" /etc/exports; then
    echo "$NFSEXPORT" >> /etc/exports
fi
exportfs -r

# 5. Configure Samba share
echo "Configuring Samba (SMB) share..."
SMB_CONF="/etc/samba/smb.conf"
if ! grep -q "^\[PXE\]" "$SMB_CONF"; then
    cat <<EOF >> "$SMB_CONF"

[PXE]
   path = $TFTP_DIR
   browseable = yes
   guest ok = yes
   read only = yes
EOF
fi

# 6. Configure FTP (vsftpd)
echo "Configuring FTP server (vsftpd)..."
VSFTPD_CONF="/etc/vsftpd.conf"
# Enable anonymous FTP and point to $TFTP_DIR
if grep -q "^anonymous_enable=" "$VSFTPD_CONF"; then
    sed -i 's/^anonymous_enable=.*/anonymous_enable=YES/' "$VSFTPD_CONF"
else
    echo "anonymous_enable=YES" >> "$VSFTPD_CONF"
fi
if grep -q "^anon_root=" "$VSFTPD_CONF"; then
    sed -i 's#^anon_root=.*#anon_root='"$TFTP_DIR"'#' "$VSFTPD_CONF"
else
    echo "anon_root=$TFTP_DIR" >> "$VSFTPD_CONF"
fi
# Disallow FTP upload (write_enable=NO for anonymous by default); we keep it read-only for safety.

# 7. Restart services to apply configuration
echo "Restarting PXE services (TFTP, NFS, SMB, FTP)..."
systemctl restart tftpd-hpa || echo "[WARN] TFTP server failed to restart"
systemctl restart nfs-kernel-server || echo "[WARN] NFS server failed to restart"
systemctl restart smbd || echo "[WARN] SMB server failed to restart"
systemctl restart vsftpd || echo "[WARN] FTP server failed to restart"

# 8. Set up rsync synchronization (primary to secondary)
if [ "$ROLE" = "primary" ]; then
    echo "Setting up rsync cron job for file sync to secondary..."
    SYNC_SCRIPT="/usr/local/bin/pxe_sync.sh"
    cat <<'EOF' > "$SYNC_SCRIPT"
#!/bin/bash
rsync -av --delete /srv/tftpboot/ 10.19.1.12:/srv/tftpboot/
EOF
    chmod +x "$SYNC_SCRIPT"
    CRON_FILE="/etc/cron.d/pxe_sync"
    if [ ! -f "$CRON_FILE" ]; then
        echo "*/5 * * * * root $SYNC_SCRIPT" > "$CRON_FILE"
    fi
    # Perform an initial sync now
    bash "$SYNC_SCRIPT" || echo "[WARN] Initial rsync sync failed. Will retry via cron."
fi

# 9. Install Docker (if not already installed via apt or present)
echo "Ensuring Docker is installed..."
if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh && sh /tmp/get-docker.sh || {
        echo "[ERROR] Docker installation failed"
        exit 1
    }
fi
# Start and enable Docker service
systemctl enable docker
systemctl start docker

# 10. Install Docker Compose (if not already available)
echo "Ensuring Docker Compose is installed..."
if ! command -v docker-compose >/dev/null 2>&1; then
    if apt-cache show docker-compose > /dev/null 2>&1; then
        apt-get install -y docker-compose || echo "[WARN] docker-compose install via apt failed, will try pip."
    fi
    if ! command -v docker-compose >/dev/null 2>&1; then
        # Fallback to pip if apt failed or not available
        apt-get install -y python3-pip && pip3 install docker-compose || {
            echo "[ERROR] Docker Compose installation failed"
            exit 1
        }
    fi
fi

# Add 'pi' user to docker group for convenience (if exists)
if id -u pi >/dev/null 2>&1; then
    usermod -aG docker pi
fi

# 11. Deploy HAProxy load balancer on primary
if [ "$ROLE" = "primary" ]; then
    echo "Deploying HAProxy load balancer (Docker container)..."
    # Create HAProxy config file
    mkdir -p /etc/haproxy
    HAPCFG="/etc/haproxy/haproxy.cfg"
    cat <<'EOF' > "$HAPCFG"
global
    log /dev/log local0
    maxconn 2000

defaults
    log global
    mode tcp
    timeout connect 5s
    timeout client  10s
    timeout server  10s

# Frontend for PXE (TFTP UDP 69)
frontend pxe_frontend
    bind *:69 udp
    mode udp
    default_backend pxe_backends

backend pxe_backends
    mode udp
    balance roundrobin
    server pi1 10.19.1.11:69 check
    server pi2 10.19.1.12:69 check
EOF

    # Run HAProxy in Docker
    docker pull haproxy:latest || echo "[WARN] Docker pull haproxy failed (using existing image if available)"
    docker stop pxe-haproxy 2>/dev/null || true
    docker rm pxe-haproxy 2>/dev/null || true
    docker run -d --name pxe-haproxy -p 69:69/udp -v /etc/haproxy/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro haproxy:latest
fi

echo "PXE setup script completed successfully at $(date). Rebooting system..."
sleep 5
reboot
