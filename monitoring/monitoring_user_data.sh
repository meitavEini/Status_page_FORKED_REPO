#!/bin/bash

exec > /var/log/user-data.log 2>&1  # שמירת לוגים

set -e  # עצירה על כל שגיאה

# Update and install required packages
apt update && apt install -y docker.io docker-compose git

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Setup monitoring directory
mkdir -p /opt/monitoring
cd /opt/monitoring

# Clone repo
git clone https://github.com/meitavEini/Status_page_FORKED_REPO.git

# Navigate to monitoring folder
cd Status_page_FORKED_REPO/monitoring

# Optional: validate docker-compose exists
if [ ! -f docker-compose.yml ]; then
  echo "❌ docker-compose.yml not found!" >&2
  exit 1
fi

# Start services
docker-compose up -d
