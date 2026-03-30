#!/bin/bash
# Run on the EC2 nginx host (via SSM). Args: <s3-bucket> <s3-key>
# App + systemd only; nginx vhost is aws-infra CDK (ec2-nginx-stack.ts).
set -euxo pipefail

BUCKET="$1"
KEY="$2"
APP_DIR="/opt/project-showcase/app"
VENV="/opt/project-showcase/venv"
TMP="/tmp/project-showcase-install-$$"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

mkdir -p "$TMP"
aws s3 cp "s3://${BUCKET}/${KEY}" "${TMP}/app.tgz"
mkdir -p "$APP_DIR"
tar xzf "${TMP}/app.tgz" -C "$APP_DIR"

if command -v python3.11 &>/dev/null; then
  PY=python3.11
elif command -v python3 &>/dev/null; then
  PY=python3
else
  echo "python3.11 and python3 not found; install Python on the host." >&2
  exit 1
fi

if [[ ! -d "${VENV}" ]]; then
  "${PY}" -m venv "${VENV}"
fi
"${VENV}/bin/pip" install --upgrade pip
"${VENV}/bin/pip" install --no-cache-dir -r "${APP_DIR}/requirements.txt"

if [[ ! -f /etc/project-showcase.env ]]; then
  echo 'APPLICATION_ROOT=/' > /etc/project-showcase.env
elif ! grep -q '^APPLICATION_ROOT=' /etc/project-showcase.env 2>/dev/null; then
  echo 'APPLICATION_ROOT=/' >> /etc/project-showcase.env
else
  sed -i 's|^APPLICATION_ROOT=.*|APPLICATION_ROOT=/|' /etc/project-showcase.env
fi
if ! grep -q '^SECRET_KEY=' /etc/project-showcase.env 2>/dev/null; then
  echo "SECRET_KEY=$(openssl rand -hex 32)" >> /etc/project-showcase.env
fi

if [[ ! -f /etc/systemd/system/project-showcase.service ]]; then
  cat > /etc/systemd/system/project-showcase.service <<'UNIT'
[Unit]
Description=Project Showcase (Gunicorn)
After=network.target

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
fi

# Root `/` → :8081 and co-paths are defined only in aws-infra (ec2-nginx-stack user data).

systemctl daemon-reload
systemctl enable project-showcase
systemctl restart project-showcase
systemctl is-active project-showcase
