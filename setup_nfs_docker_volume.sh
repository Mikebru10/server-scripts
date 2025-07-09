#!/bin/bash

# Configuration
NFS_SERVER="10.19.0.11"
NFS_SHARE="/mnt/main-04/docker_nfs"
LOCAL_MOUNT="/mnt/docker_nfs"
FSTAB_ENTRY="$NFS_SERVER:$NFS_SHARE $LOCAL_MOUNT nfs vers=3,_netdev 0 0"

echo "🔧 Installing NFS client tools..."
sudo apt update && sudo apt install -y nfs-common

echo "📁 Creating local mount directory..."
sudo mkdir -p "$LOCAL_MOUNT"

echo "🔌 Mounting NFSv3 share..."
sudo mount -t nfs -o vers=3 "$NFS_SERVER:$NFS_SHARE" "$LOCAL_MOUNT"
if [ $? -ne 0 ]; then
  echo "❌ Failed to mount NFS share. Please check network and NFS server config."
  exit 1
fi

echo "💾 Checking if fstab already has entry..."
grep -qs "$NFS_SHARE" /etc/fstab
if [ $? -ne 0 ]; then
  echo "📝 Adding mount to /etc/fstab..."
  echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab
else
  echo "✅ fstab entry already exists. Skipping..."
fi

echo "✅ NFS share mounted and ready for Docker bind-mounts:"
echo "   -> $NFS_SERVER:$NFS_SHARE -> $LOCAL_MOUNT"
