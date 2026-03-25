#!/bin/bash
set -e

echo "Updating system..."
sudo dnf update -y

echo "Adding Jenkins repo..."
sudo wget -O /etc/yum.repos.d/jenkins.repo \
  https://pkg.jenkins.io/rpm-stable/jenkins.repo

echo "Importing Jenkins key..."
sudo rpm --import https://pkg.jenkins.io/rpm-stable/jenkins.io-2026.key

echo "Installing Java..."
sudo dnf install -y fontconfig java-21-openjdk

echo "Installing Jenkins..."
sudo dnf install -y jenkins

echo "Reloading systemd..."
sudo systemctl daemon-reexec

echo "Enabling Jenkins..."
sudo systemctl enable jenkins

echo "Starting Jenkins..."
sudo systemctl start jenkins

echo "Checking Jenkins status..."
sudo systemctl status jenkins --no-pager
