#!/bin/bash
set -e

yum update -y
yum install -y docker git

systemctl enable docker
systemctl start docker

usermod -a -G docker ec2-user

cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

systemctl restart docker

cat > /etc/systemd/system/flask-api.service <<EOF
[Unit]
Description=Flask API Container
Requires=docker.service
After=docker.service

[Service]
Restart=always
ExecStartPre=-/usr/bin/docker rm flask-api
ExecStart=/usr/bin/docker run --name flask-api \
  -p 5000:5000 \
  -e ENVIRONMENT=production \
  --restart unless-stopped \
  flask-api:latest
ExecStop=/usr/bin/docker stop flask-api
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable flask-api
