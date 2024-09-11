#!/bin/bash

# Script to update, upgrade, and clean up packages on Ubuntu

echo "Updating package lists..."
sudo apt-get update

echo "Upgrading installed packages..."
sudo apt-get upgrade -y

echo "Performing distribution upgrade..."
sudo apt-get dist-upgrade -y

echo "Removing obsolete packages..."
sudo apt-get autoremove -y

echo "Cleaning up..."
sudo apt-get autoclean

echo "Checking for a new release of Ubuntu..."
sudo do-release-upgrade -m desktop

echo "Update and upgrade process completed."



