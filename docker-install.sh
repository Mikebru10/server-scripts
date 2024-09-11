  GNU nano 7.2                                                                                           docker-install.sh                                                                                                    
#!/bin/bash

# Set -e to exit on error
set -e

# Update your existing list of packages
echo "Updating package list..."
sudo apt-get update

# Install prerequisite packages
echo "Installing prerequisites..."
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common lsb-release

# Add Docker’s official GPG key
echo "Adding Docker's GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "Adding Docker repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > />

# Update the package database with Docker packages
echo "Updating package database..."
sudo apt-get update

# Install Docker CE
echo "Installing Docker..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Post-installation steps to allow management of Docker as a non-root user
echo "Configuring Docker for non-root user..."
sudo groupadd docker || true
sudo usermod -aG docker $USER

# Install Docker Compose
echo "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/v2.5.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
echo "Verifying installations..."
docker --version
docker-compose --version

echo "Docker and Docker Compose installation has been completed successfully."
