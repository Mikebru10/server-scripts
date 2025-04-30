#!/bin/bash

# Define variables
REPO_URL="https://github.com/Mikebru10/server-scripts.git"
DEST_DIR="/home/$USER/server-scripts"

echo "[*] Updating package list..."
sudo apt-get update -y

echo "[*] Installing Git if not present..."
sudo apt-get install -y git

# Check if destination directory already exists
if [ -d "$DEST_DIR" ]; then
  echo "[!] Directory $DEST_DIR already exists."
  read -p "Do you want to delete it and re-clone the repo? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "[*] Removing existing directory..."
    rm -rf "$DEST_DIR"
  else
    echo "[*] Aborting clone."
    exit 1
  fi
fi

echo "[*] Cloning repository..."
git clone "$REPO_URL" "$DEST_DIR"

if [ $? -eq 0 ]; then
  echo "[✓] Repository cloned successfully to $DEST_DIR"
else
  echo "[✗] Failed to clone repository."
  exit 1
fi
