#!/bin/bash
set -e

echo "Updating system..."
 sudo yum update –y

echo "Adding Jenkins repo..."
sudo wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/rpm-stable/jenkins.repo

echo "Importing Jenkins key..."
sudo rpm --import https://pkg.jenkins.io/rpm-stable/jenkins.io-2026.key

echo "Upgrade"
sudo yum upgrade

echo "Installing Java..."
sudo yum install java-21-amazon-corretto -y

echo "Installing Jenkins..."
sudo yum install jenkins -y

echo "Enabling Jenkins..."
sudo systemctl enable jenkins

echo "Starting Jenkins..."
sudo systemctl start jenkins

echo "Checking Jenkins status..."
sudo systemctl status jenkins
