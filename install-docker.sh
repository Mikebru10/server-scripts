#!/usr/bin/env bash

# Exit on errors and enable debug output
set -euo pipefail

echo "=== Updating apt and installing prerequisites ==="
sudo apt-get update -y
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    gnupg2

echo "=== Adding Docker’s official GPG key ==="
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "=== Adding Docker APT repository ==="
# For Ubuntu 24.10, the codename is 'mantic' (though Docker may not yet have official support).
# You can override CODENAME if Docker isn't providing a repo for 24.10 yet.
CODENAME="$(lsb_release -cs)"
echo "Using codename: $CODENAME"

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu $CODENAME stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

echo "=== Updating apt again ==="
sudo apt-get update -y

echo "=== Installing Docker Engine, CLI, Containerd, and Docker Compose plugin ==="
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "=== Enabling and starting Docker service ==="
sudo systemctl enable docker
sudo systemctl start docker

echo "=== Verifying Docker version ==="
docker --version

echo "=== Verifying Docker Compose plugin ==="
docker compose version || {
  echo "Docker Compose (plugin) is not available. Check logs for errors."
  exit 1
}

echo "=== Installation complete! ==="
echo "If you want to run docker without sudo, add your user to the 'docker' group by running:"
echo "  sudo usermod -aG docker \$USER"
echo "Then log out and log back in, or reboot."
