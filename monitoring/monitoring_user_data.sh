#!/bin/bash

# Update and install required packages
apt update && apt install -y docker.io docker-compose git

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Create monitoring directory and clone the repo
mkdir -p /opt/monitoring
cd /opt/monitoring

# Clone your GitHub repository (if not already cloned)
git clone https://github.com/meitavEini/Status_page_FORKED_REPO.git

# Navigate to the folder where your docker-compose and config files are
cd Status_page_FORKED_REPO/monitoring

# Start the services with docker-compose
docker-compose up -d
