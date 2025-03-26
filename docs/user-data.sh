#!/bin/bash

# Update system and install basic packages
sudo apt update && sudo apt install -y git docker.io docker-compose # apt update && apt install -y git docker.io docker-compose

# Add ubuntu user to docker group
sudo usermod -aG docker ubuntu # sudo usermod -aG sudo ubuntu

newgrp docker # newgrp sudo

# Clone your repository
mkdir -p /opt/status-page # sudo mkdir -p /opt/status-page
cd /opt/status-page
git clone https://github.com/meitavEini/Status_page_FORKED_REPO.git .
git checkout main

sleep 10

# Run the app
sudo docker-compose -f docker-compose.yml up -d --build
