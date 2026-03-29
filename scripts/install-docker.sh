#!/bin/bash

set -e

echo "Installing Docker"
sudo dnf install -y docker

echo "👥 Ensuring docker group exists..."
if ! getent group docker > /dev/null; then
  sudo groupadd docker
fi

echo "👤 Adding user to docker group..."
sudo usermod -aG docker "$USER"

echo "🚀 Enabling and starting Docker services..."
sudo systemctl enable --now docker.service
sudo systemctl enable --now containerd.service

echo "🔍 Verifying Docker installation..."
sudo docker --version

echo "⚠️ NOTE: Log out and log back in to use Docker without sudo."