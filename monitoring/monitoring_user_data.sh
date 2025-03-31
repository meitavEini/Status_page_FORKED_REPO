#!/bin/bash

apt update && apt install -y docker.io docker-compose git awscli

systemctl enable docker
systemctl start docker

mkdir -p /opt/monitoring
cd /opt/monitoring

# Create prometheus.yml
cat > prometheus.yml <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'ec2-node-exporters'
    ec2_sd_configs:
      - region: us-east-1
        port: 9100
        filters:
          - name: tag:role
            values: ['statuspage']
    relabel_configs:
      - source_labels: [__meta_ec2_tag_Name]
        target_label: instance
      - source_labels: [__meta_ec2_private_ip]
        target_label: private_ip
      - source_labels: [__meta_ec2_instance_id]
        target_label: instance_id
EOF

# Create docker-compose.yml
cat > docker-compose.yml <<EOF
version: '3'

services:
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    restart: always

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin  # בסביבת ייצור יש להחליף לסיסמה חזקה
    depends_on:
      - prometheus
    restart: always

volumes:
  prometheus_data:
  grafana_data:
EOF

# Get AWS metadata to allow EC2 instance profile to work
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)

# Start the monitoring stack
docker-compose up -d