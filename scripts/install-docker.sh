#!/bin/bash
sudo dnf install docker -y

#post-installation steps
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
sudo systemctl start docker.service