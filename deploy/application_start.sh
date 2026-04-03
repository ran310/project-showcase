#!/bin/bash
set -euxo pipefail

cat > /etc/systemd/system/project-showcase.service <<'UNIT'
[Unit]
Description=Project Showcase (Gunicorn)
After=network.target
ConditionPathExists=/opt/project-showcase/venv/bin/gunicorn

[Service]
Type=simple
User=root
WorkingDirectory=/opt/project-showcase/app
EnvironmentFile=/etc/project-showcase.env
ExecStart=/opt/project-showcase/venv/bin/gunicorn --bind 127.0.0.1:8081 app:app
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable project-showcase
systemctl restart project-showcase
systemctl is-active project-showcase
