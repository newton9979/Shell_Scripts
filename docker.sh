#!/bin/bash

# ==========================================================
# Script Name : docker-install.sh
# Purpose     : Install Docker on Ubuntu EC2 Instance
# Author      : Newton
# ==========================================================

# Redirect all output to log file
exec > >(tee /var/log/docker-install.log) 2>&1

echo "=================================================="
echo "Docker Installation Started : $(date)"
echo "=================================================="

# Update packages
echo "Updating Ubuntu packages..."

if sudo apt update -y; then
    echo "Package update completed."
else
    echo "ERROR: Package update failed."
    exit 1
fi

# Check whether Docker is already installed
if command -v docker &>/dev/null; then
    echo "Docker is already installed."
    docker -v
else
    echo "Docker is not installed."
    echo "Installing Docker..."

    # Install Docker from Ubuntu Repository
    if sudo apt install docker.io -y; then
        echo "Docker installed successfully."
    else
        echo "ERROR: Docker installation failed."
        exit 1
    fi
fi

# Enable Docker service
echo "Enabling Docker service..."

sudo systemctl enable docker

# Start Docker service
echo "Starting Docker service..."

sudo systemctl start docker

# Check service status
if systemctl is-active --quiet docker; then
    echo "Docker service is running."
else
    echo "ERROR: Docker service failed to start."
    systemctl status docker --no-pager
    exit 1
fi

# Verify Docker Version
echo "Docker Version:"
docker --version

# Verify Docker daemon
echo "Checking Docker daemon..."

if ps -ef | grep dockerd | grep -v grep >/dev/null; then
    echo "Docker daemon is running."
else
    echo "ERROR: Docker daemon is NOT running."
    exit 1
fi

# Add ubuntu user to docker group
if id ubuntu &>/dev/null; then
    echo "Adding ubuntu user to docker group..."
    sudo usermod -aG docker ubuntu
    echo "User added successfully."
else
    echo "ubuntu user not found. Skipping."
fi

# Test Docker
echo "Running Docker test..."

if sudo docker ps >/dev/null 2>&1; then
    echo "Docker is working correctly."
else
    echo "ERROR: Docker command failed."
    exit 1
fi

echo "=================================================="
echo "Docker Installation Completed Successfully"
echo "Time : $(date)"
echo "=================================================="
